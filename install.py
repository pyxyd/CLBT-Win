#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CLBT 安装器
===========

作用：
  1. 把 terminal-setup.cmd 装到安装目录（默认 C:\\Program Files\\CLBT）
  2. 在同一目录生成 CLBT.cmd（命令行入口，转发到 terminal-setup.cmd）
  3. 把该目录加入「当前用户」的 PATH，之后任何新开的终端都能直接敲 CLBT
  4. 清理旧位置残留的 CLBT 安装（避免 PATH 里旧路径抢先命中旧版本）

用法：
  python install.py                       # 安装到 C:\\Program Files\\CLBT（会触发 UAC 提权）
  python install.py --dir D:\\tools\\clbt  # 装到别处（不需要管理员）
  python install.py --uninstall           # 从 PATH 移除并删除工具文件
  python install.py --help

注意：
  · 默认目录在 Program Files 下，写入需要一次 UAC 授权；用 --dir 指到当前用户可写的
    目录就可以完全免提权
  · 只修改 HKCU 的用户 PATH，不动系统级 PATH；重复运行不会产生重复项
  · 修改后需要重开终端（或重新登录）才会生效
"""

import argparse
import ctypes
import glob
import hashlib
import os
import shutil
import subprocess
import sys
import time
from ctypes import wintypes

try:
    import winreg
except ImportError:  # 非 Windows
    print("这个安装器只能在 Windows 上运行。")
    sys.exit(1)

if getattr(sys, "frozen", False):
    # PyInstaller 打包成 exe 后，__file__ 指向临时解包目录，
    # 必须用 exe 自身所在目录，否则会去找不到 terminal-setup.cmd
    HERE = os.path.dirname(os.path.abspath(sys.executable))
else:
    HERE = os.path.dirname(os.path.abspath(__file__))
TOOL_NAME = "terminal-setup.cmd"
GUI_NAME = "CLBT-GUI.exe"
CLBT_NAME = "CLBT.cmd"

# 默认安装目录：C:\Program Files\CLBT（跟其它 Windows 程序放一起）
PROGRAM_FILES = os.environ.get("ProgramFiles") or r"C:\Program Files"
DEFAULT_DIR = os.path.join(PROGRAM_FILES, "CLBT")

CLBT_TEMPLATE = """@echo off
rem  ============================================================
rem   CLBT - command line entry of the Windows terminal beautify tool
rem   The real logic lives in terminal-setup.cmd; this only forwards args.
rem   Usage:  CLBT -help
rem   Note: keep this file ASCII-only (cmd reads it as ANSI, not UTF-8).
rem  ============================================================
call "%~dp0{target}" %*
"""


def say(msg=""):
    print(msg)


def _fix_stdout_encoding():
    """让中文在各场景都正确：
       · 直连控制台（双击运行）-> Python 走 WriteConsoleW，天然 Unicode，不动
       · 输出被重定向（管道/文件）-> 统一用 UTF-8，避免消费端编码不一致
    """
    try:
        if sys.stdout is None or sys.stdout.isatty():
            return
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if sys.stderr is not None:
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def _pause_if_interactive(no_pause):
    """双击 exe 时窗口会立刻关闭，这里停一下让人看清结果"""
    if no_pause:
        return
    try:
        if sys.stdin is not None and sys.stdin.isatty() and sys.stdout is not None and sys.stdout.isatty():
            print()
            input("  按回车键退出 . . .")
    except Exception:
        pass


# ---------------------------------------------------------------- 权限

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def _can_write(path):
    """能否在 path 下创建文件（不存在就往上找到最近的已存在目录试）"""
    probe_dir = path
    while probe_dir and not os.path.isdir(probe_dir):
        parent = os.path.dirname(probe_dir.rstrip("\\/"))
        if parent == probe_dir:
            break
        probe_dir = parent
    if not probe_dir or not os.path.isdir(probe_dir):
        return False
    probe = os.path.join(probe_dir, f".clbt-probe-{os.getpid()}")
    try:
        with open(probe, "wb") as f:
            f.write(b"x")
        os.remove(probe)
        return True
    except Exception:
        return False


def needs_elevation(target_dir):
    if is_admin():
        return False
    return not _can_write(target_dir)


class SHELLEXECUTEINFOW(ctypes.Structure):
    _fields_ = [
        ("cbSize", wintypes.DWORD),
        ("fMask", ctypes.c_ulong),
        ("hwnd", wintypes.HWND),
        ("lpVerb", wintypes.LPCWSTR),
        ("lpFile", wintypes.LPCWSTR),
        ("lpParameters", wintypes.LPCWSTR),
        ("lpDirectory", wintypes.LPCWSTR),
        ("nShow", ctypes.c_int),
        ("hInstApp", wintypes.HINSTANCE),
        ("lpIDList", ctypes.c_void_p),
        ("lpClass", wintypes.LPCWSTR),
        ("hkeyClass", wintypes.HKEY),
        ("dwHotKey", wintypes.DWORD),
        ("hIconOrMon", wintypes.HANDLE),
        ("hProcess", wintypes.HANDLE),
    ]


def run_elevated(args):
    """用 runas 重新启动自身（带上原参数），等它结束后返回退出码。
       用户点「否」时返回 1223，其它失败返回 False。"""
    if getattr(sys, "frozen", False):
        exe, params = sys.executable, subprocess.list2cmdline(args)
    else:
        exe, params = sys.executable, subprocess.list2cmdline([os.path.abspath(__file__)] + args)

    shell32 = ctypes.WinDLL("shell32", use_last_error=True)
    shell32.ShellExecuteExW.argtypes = [ctypes.POINTER(SHELLEXECUTEINFOW)]
    shell32.ShellExecuteExW.restype = wintypes.BOOL

    sei = SHELLEXECUTEINFOW()
    sei.cbSize = ctypes.sizeof(sei)
    sei.fMask = 0x00000040  # SEE_MASK_NOCLOSEPROCESS
    sei.lpVerb = "runas"
    sei.lpFile = exe
    sei.lpParameters = params or None
    sei.nShow = 1

    if not shell32.ShellExecuteExW(ctypes.byref(sei)):
        return ctypes.get_last_error() or False

    try:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.WaitForSingleObject(sei.hProcess, 0xFFFFFFFF)
        code = wintypes.DWORD()
        kernel32.GetExitCodeProcess(sei.hProcess, ctypes.byref(code))
        kernel32.CloseHandle(sei.hProcess)
        return code.value
    except Exception:
        return 0


def elevate_if_needed(target_dir, argv, no_elevate):
    """需要管理员权限时提权重跑整个安装/卸载流程。
       返回 None 表示「无需提权」；返回整数表示已提权，直接用它当退出码。"""
    if "--elevated" in argv or no_elevate or not needs_elevation(target_dir):
        return None

    say()
    say(f"    目录需要管理员权限: {target_dir}")
    say("    正在请求 UAC 授权，请在弹出的窗口里点「是」 . . .")
    code = run_elevated([a for a in argv] + ["--elevated"])
    if code == 1223:  # ERROR_CANCELLED
        say("    [XX] 已取消授权，安装没有进行。")
        return 1
    if code is False:
        say("    [XX] 无法启动提权进程。")
        return 1
    if code == 0:
        say("    已在管理员窗口中完成。")
    else:
        say(f"    [!] 提权进程返回代码 {code}，请检查上面的输出。")
    return code


# ---------------------------------------------------------------- PATH

def user_path_get():
    """读取当前用户 PATH（保持原有类型 REG_SZ / REG_EXPAND_SZ）"""
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0,
                         winreg.KEY_READ)
    try:
        val, typ = winreg.QueryValueEx(key, "Path")
    except FileNotFoundError:
        val, typ = "", winreg.REG_EXPAND_SZ
    finally:
        winreg.CloseKey(key)
    return val or "", typ


def user_path_set(value, typ):
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0,
                         winreg.KEY_READ | winreg.KEY_WRITE)
    try:
        if typ not in (winreg.REG_SZ, winreg.REG_EXPAND_SZ):
            typ = winreg.REG_EXPAND_SZ
        winreg.SetValueEx(key, "Path", 0, typ, value)
    finally:
        winreg.CloseKey(key)
    broadcast_env_change()


def broadcast_env_change():
    """通知资源管理器环境变量变了（新开的终端才能拿到新 PATH）"""
    HWND_BROADCAST = 0xFFFF
    WM_SETTINGCHANGE = 0x001A
    SMTO_ABORTIFHUNG = 0x0002
    result = ctypes.c_ulong()
    try:
        ctypes.windll.user32.SendMessageTimeoutW(
            HWND_BROADCAST, WM_SETTINGCHANGE, 0, ctypes.c_wchar_p("Environment"),
            SMTO_ABORTIFHUNG, 5000, ctypes.byref(result))
    except Exception:
        pass  # 通知失败不影响 PATH 写入


def path_entries(value):
    return [p for p in (value or "").split(";") if p.strip()]


def normalize(p):
    return os.path.normcase(os.path.normpath(p.strip().strip('"')))


# ---------------------------------------------------------------- 文件

def bundled_tool_path():
    """返回 terminal-setup.cmd 的来源路径：
       1) PyInstaller 打包后 -> exe 内部解包目录（自带）
       2) 未打包时 -> 与本脚本同级
    """
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        p = os.path.join(meipass, TOOL_NAME)
        if os.path.isfile(p):
            return p, True
    return os.path.join(HERE, TOOL_NAME), False


def bundled_gui_path():
    """返回安装器里带的图形界面 exe（没带则返回不存在路径）"""
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        p = os.path.join(meipass, GUI_NAME)
        if os.path.isfile(p):
            return p
    return os.path.join(HERE, GUI_NAME)


def same_content(a, b):
    """两个文件内容是否完全一致。只比大小不行：只改版本号的更新字节数一样，
    会被当成"已是最新"跳过（实测 v1.1.3 -> v1.1.4 就是这样漏更的）。"""
    try:
        if os.path.getsize(a) != os.path.getsize(b):
            return False
        h = hashlib.sha256()
        with open(a, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        d1 = h.hexdigest()
        h = hashlib.sha256()
        with open(b, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        return d1 == h.hexdigest()
    except Exception:
        return False


def ensure_crlf(path):
    """把批处理文件的行尾规范成 CRLF。
    LF 行尾会让 cmd 把内嵌的 PowerShell 正文当成命令执行，
    表现是一堆「xxx 不是内部或外部命令」。返回是否做了修正。
    """
    try:
        with open(path, "rb") as f:
            data = f.read()
        head = data[:8192]
        if b"\r\n" in head or b"\n" not in head:
            return False
        fixed = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        with open(path, "wb") as f:
            f.write(fixed)
        return True
    except Exception:
        return False


def remove_tool_files(directory, verbose=True):
    """删掉某目录里的 CLBT.cmd / terminal-setup.cmd（及其 .bak 备份）"""
    removed = []
    for name in (CLBT_NAME, TOOL_NAME, GUI_NAME):
        p = os.path.join(directory, name)
        for f in [p] + glob.glob(p + ".bak*"):
            if os.path.isfile(f):
                try:
                    os.remove(f)
                    removed.append(f)
                except Exception as e:
                    say(f"    [!] 删除失败 {f}: {e}")
    if removed and verbose:
        for f in removed:
            say(f"    已删除: {f}")
    return removed


def enable_utf8_cmd(target_dir):
    """调用工具把 Terminal 里的 cmd 标签改成 UTF-8 启动（解决 bat 中文乱码）。
       失败不影响安装本身。"""
    tool = os.path.join(target_dir, TOOL_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run(
            ["cmd", "/c", tool, "-encoding", "on", "/y"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=180)
        return r.returncode == 0
    except Exception as e:
        print(f"    [!] 自动编码设置失败: {e}")
        return False


def legacy_installs(target_dir):
    """用户 PATH 里其它「装过 CLBT」的目录（判断依据：目录里有 CLBT.cmd）"""
    cur, _ = user_path_get()
    out = []
    for e in path_entries(cur):
        if normalize(e) == normalize(target_dir):
            continue
        if os.path.isfile(os.path.join(e, CLBT_NAME)):
            out.append(e)
    return out


# ---------------------------------------------------------------- 安装 / 卸载

def do_install(target_dir, do_encoding=True, keep_old=False):
    src, embedded = bundled_tool_path()
    if not os.path.isfile(src):
        say(f"[XX] 找不到 {TOOL_NAME}。")
        say("     如果你拿到的是未打包版本，请把 terminal-setup.cmd 放在本脚本同级目录。")
        return 1

    target_dir = os.path.abspath(target_dir)
    try:
        os.makedirs(target_dir, exist_ok=True)
    except Exception as e:
        say(f"[XX] 无法创建安装目录 {target_dir}: {e}")
        return 1
    say(f"    安装目录: {target_dir}")

    # 1) 把工具写到目标目录（自带的那份优先）
    dst_tool = os.path.join(target_dir, TOOL_NAME)
    src_size = os.path.getsize(src)
    if os.path.isfile(dst_tool) and same_content(dst_tool, src):
        say(f"    工具本体已是最新，跳过: {dst_tool}")
    else:
        if os.path.isfile(dst_tool):
            bak = dst_tool + ".bak"
            try:
                shutil.copy2(dst_tool, bak)
                say(f"    旧文件已备份: {os.path.basename(bak)}")
            except Exception:
                pass
        try:
            shutil.copy2(src, dst_tool)
        except Exception as e:
            say(f"[XX] 写入失败 {dst_tool}: {e}")
            say("     如果目标目录在 Program Files 下，请用管理员权限运行安装器。")
            return 1
        how = "从安装器内释放" if embedded else "已复制"
        say(f"    {how}: {dst_tool}  ({src_size / 1048576:.2f} MB)")

    # 图形界面（install.exe 里带了就一起装）
    gui_src = bundled_gui_path()
    if os.path.isfile(gui_src):
        gui_dst = os.path.join(target_dir, GUI_NAME)
        written = False
        for attempt in range(6):
            try:
                if os.path.isfile(gui_dst) and same_content(gui_dst, gui_src):
                    say(f"    图形界面已是最新，跳过: {gui_dst}")
                    written = True
                    break
                shutil.copy2(gui_src, gui_dst)
                say(f"    图形界面: {gui_dst}  ({os.path.getsize(gui_src) / 1048576:.2f} MB)")
                written = True
                break
            except Exception as e:  # noqa: BLE001
                # 最常见：CLBT-GUI.exe 还开着，文件被占用。等它一会儿再试
                if attempt == 0:
                    say(f"    [!] 图形界面正在使用中，正在重试（关掉 CLBT-GUI.exe 会更快）: {e}")
                time.sleep(2.0)
        if not written:
            say("    [XX] 图形界面没能更新：请先关掉所有 CLBT-GUI.exe 窗口，然后重新运行 install.exe")

    # 行尾自检：LF 会让 cmd 误执行内嵌脚本
    if ensure_crlf(dst_tool):
        say("    已修正行尾为 CRLF（原文件是 LF，会导致 cmd 报一堆「不是内部或外部命令」）")
    else:
        ok_crlf = True
        try:
            with open(dst_tool, "rb") as f:
                ok_crlf = b"\r\n" in f.read(8192)
        except Exception:
            pass
        if not ok_crlf:
            say("    [XX] 该文件行尾不是 CRLF，运行会报错，请重新获取原始文件")

    # 2) 生成 CLBT.cmd
    clbt = os.path.join(target_dir, CLBT_NAME)
    content = CLBT_TEMPLATE.format(target=TOOL_NAME).replace("\r\n", "\n").replace("\n", "\r\n")
    try:
        with open(clbt, "w", encoding="utf-8", newline="") as f:
            f.write(content)
        say(f"    已生成入口命令: {clbt}")
    except Exception as e:
        say(f"[XX] 写入 {clbt} 失败: {e}")
        return 1

    # 3) 写入用户 PATH
    cur, typ = user_path_get()
    entries = path_entries(cur)
    if any(normalize(e) == normalize(target_dir) for e in entries):
        say("    PATH 里已经有这个目录，无需重复添加")
    else:
        new_val = ";".join(entries + [target_dir])
        user_path_set(new_val, typ)
        say(f"    已加入用户 PATH: {target_dir}")

    # 4) 清理旧位置（否则 PATH 里旧路径可能抢先命中旧版本）
    olds = legacy_installs(target_dir)
    if olds:
        if keep_old:
            for o in olds:
                say(f"    [!] 旧安装仍在: {o}（--keep-old 已保留，命令行可能命中旧版本）")
        else:
            for o in olds:
                # 旧目录可能在没有权限的地方（例如 Program Files）：先探一下再动，
                # 否则会「文件删不掉但 PATH 已经移除」，命令直接消失
                if not _can_write(o):
                    say(f"    [!] 旧安装 {o} 需要管理员权限才能清理，已跳过（PATH 保持不变）")
                    say("        想清掉它，用管理员身份再跑一次本安装器，或执行 install.exe --uninstall")
                    continue
                say(f"    发现旧安装，正在清理: {o}")
                remove_tool_files(o)
                cur2, typ2 = user_path_get()
                kept = [e for e in path_entries(cur2) if normalize(e) != normalize(o)]
                if len(kept) != len(path_entries(cur2)):
                    user_path_set(";".join(kept), typ2)
                try:
                    if os.path.isdir(o) and not os.listdir(o):
                        os.rmdir(o)
                        say(f"    已删除空目录: {o}")
                except Exception:
                    pass

    # 自动让 cmd 标签以 UTF-8 启动（bat 中文不乱码）
    if do_encoding:
        if enable_utf8_cmd(target_dir):
            say("    已让 Terminal 的 cmd 标签以 UTF-8 启动（运行 UTF-8 编码的 .bat 不再乱码）")
        else:
            say("    [!] 未能自动设置 UTF-8 代码页，可稍后手动执行: CLBT -encoding on")

    say()
    say("安装完成。请【重新打开终端】后使用：")
    say("    CLBT -help")
    say("    CLBT -linux")
    say("    CLBT -win")
    say("    CLBT -transparent 50 -linux")
    say()
    say("图形界面：双击 " + os.path.join(target_dir, GUI_NAME) + "　或命令行输入 CLBT -gui")
    say(f"卸载：{os.path.basename(sys.executable)} --uninstall")
    return 0


def do_uninstall(target_dir):
    target_dir = os.path.abspath(target_dir)
    say(f"    安装目录: {target_dir}")

    # 1) PATH 里所有「装过 CLBT」的目录都清掉（没权限的跳过，别把 PATH 弄空）
    cur, typ = user_path_get()
    entries = path_entries(cur)
    dead = [e for e in entries
            if normalize(e) == normalize(target_dir)
            or os.path.isfile(os.path.join(e, CLBT_NAME))]
    removable, skipped = [], []
    for d in dead:
        if normalize(d) != normalize(target_dir) and not _can_write(d):
            skipped.append(d)
        else:
            removable.append(d)

    if not removable:
        say("    PATH 中没有可清理的目录")
    else:
        kept = [e for e in entries if e not in removable]
        user_path_set(";".join(kept), typ)
        for d in removable:
            say(f"    已从用户 PATH 移除: {d}")
    for d in skipped:
        say(f"    [!] {d} 需要管理员权限才能清理，已跳过（PATH 保持不变）")
        say("        想清掉它，用管理员身份重跑：install.exe --uninstall")

    # 2) 删掉工具文件（含旧位置的残留副本）
    for d in sorted(set(removable) | {target_dir}):
        if os.path.isdir(d):
            remove_tool_files(d)

    # 3) 目录空了就一起删掉
    try:
        if os.path.isdir(target_dir) and not os.listdir(target_dir):
            os.rmdir(target_dir)
            say(f"    已删除目录: {target_dir}")
    except Exception:
        pass

    say()
    say("卸载完成。请重新打开终端使其生效。")
    return 0


def main():
    _fix_stdout_encoding()
    ap = argparse.ArgumentParser(
        prog="install.exe",
        description="安装 CLBT 命令行美化工具（默认装到 C:\\Program Files\\CLBT，写入当前用户 PATH）",
        formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument("--dir", default=DEFAULT_DIR,
                    help=f"安装目录（默认：{DEFAULT_DIR}）\n指到当前用户可写的目录可免提权")
    ap.add_argument("--uninstall", action="store_true",
                    help="从 PATH 移除并删除 CLBT.cmd / terminal-setup.cmd")
    ap.add_argument("--no-pause", action="store_true", help="不等待回车（脚本化调用用）")
    ap.add_argument("--no-encoding", action="store_true",
                    help="不自动开启 UTF-8 代码页（默认会开启，解决 bat 中文乱码）")
    ap.add_argument("--keep-old", action="store_true",
                    help="不清理旧位置（默认会删掉旧目录里的 CLBT.cmd / terminal-setup.cmd）")
    ap.add_argument("--no-elevate", action="store_true",
                    help="不要自动请求管理员权限，遇到权限不足直接失败")
    ap.add_argument("--elevated", action="store_true", help=argparse.SUPPRESS)
    args = ap.parse_args()

    say()
    say("  || CLBT 安装器 | Windows 命令行美化工具 ||")
    say()

    argv = sys.argv[1:]
    code = elevate_if_needed(args.dir, argv, args.no_elevate)
    if code is not None:
        return code

    if args.uninstall:
        rc = do_uninstall(args.dir)
    else:
        rc = do_install(args.dir, do_encoding=not args.no_encoding, keep_old=args.keep_old)
    _pause_if_interactive(getattr(args, "no_pause", False))
    return rc


if __name__ == "__main__":
    sys.exit(main())
