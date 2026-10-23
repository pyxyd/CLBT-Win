#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CLBT 安装器
===========

作用：
  1. 确保 terminal-setup.cmd 在目标文件夹里（默认与本脚本同级）
  2. 在同级生成 CLBT.cmd（命令行入口，转发到 terminal-setup.cmd）
  3. 把该文件夹加入「当前用户」的 PATH 环境变量，之后任何新开的终端都能直接敲 CLBT

用法：
  python install.py                 # 安装到本脚本所在目录
  python install.py --dir D:\\tools\\clbt
  python install.py --uninstall     # 从 PATH 移除并删除 CLBT.cmd
  python install.py --help

注意：
  · 只修改 HKCU 的用户 PATH，不需要管理员权限，不动系统级 PATH
  · 已存在的 PATH 条目会被保留，重复运行不会产生重复项
  · 修改后需要重开终端（或重新登录）才会生效
"""

import argparse
import ctypes
import os
import shutil
import subprocess
import sys

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
CLBT_NAME = "CLBT.cmd"

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


def do_install(target_dir, do_encoding=True):
    src, embedded = bundled_tool_path()
    if not os.path.isfile(src):
        say(f"[XX] 找不到 {TOOL_NAME}。")
        say("     如果你拿到的是未打包版本，请把 terminal-setup.cmd 放在本脚本同级目录。")
        return 1

    target_dir = os.path.abspath(target_dir)
    os.makedirs(target_dir, exist_ok=True)

    # 1) 把工具写到目标目录（自带的那份优先）
    dst_tool = os.path.join(target_dir, TOOL_NAME)
    src_size = os.path.getsize(src)
    if os.path.isfile(dst_tool) and os.path.getsize(dst_tool) == src_size:
        say(f"    工具本体已是最新，跳过: {dst_tool}")
    else:
        if os.path.isfile(dst_tool):
            bak = dst_tool + ".bak"
            try:
                shutil.copy2(dst_tool, bak)
                say(f"    旧文件已备份: {os.path.basename(bak)}")
            except Exception:
                pass
        shutil.copy2(src, dst_tool)
        how = "从安装器内释放" if embedded else "已复制"
        say(f"    {how}: {dst_tool}  ({src_size / 1048576:.2f} MB)")

    # 行尾自检：LF 会让 cmd 误执行内嵌脚本
    if ensure_crlf(dst_tool):
        bak = dst_tool + ".bak-lf"
        try:
            if not os.path.isfile(bak):
                with open(dst_tool, "rb") as f:
                    pass
        except Exception:
            pass
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
    with open(clbt, "w", encoding="utf-8", newline="") as f:
        f.write(content)
    say(f"    已生成入口命令: {clbt}")

    # 3) 写入用户 PATH
    cur, typ = user_path_get()
    entries = path_entries(cur)
    if any(normalize(e) == normalize(target_dir) for e in entries):
        say(f"    PATH 里已经有这个目录，无需重复添加")
    else:
        new_val = ";".join(entries + [target_dir])
        user_path_set(new_val, typ)
        say(f"    已加入用户 PATH: {target_dir}")

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
    say(f"卸载：{os.path.basename(sys.executable)} --uninstall")
    return 0


def do_uninstall(target_dir):
    target_dir = os.path.abspath(target_dir)

    cur, typ = user_path_get()
    entries = path_entries(cur)
    kept = [e for e in entries if normalize(e) != normalize(target_dir)]
    if len(kept) == len(entries):
        say("    PATH 中没有该目录，跳过")
    else:
        user_path_set(";".join(kept), typ)
        say(f"    已从用户 PATH 移除: {target_dir}")

    clbt = os.path.join(target_dir, CLBT_NAME)
    if os.path.isfile(clbt):
        os.remove(clbt)
        say(f"    已删除: {clbt}")

    say()
    say("卸载完成。请重新打开终端使其生效。")
    return 0


def main():
    _fix_stdout_encoding()
    ap = argparse.ArgumentParser(
        prog="install.py",
        description="安装 CLBT 命令行美化工具（写入当前用户 PATH，无需管理员）")
    ap.add_argument("--dir", default=HERE, help="安装目录（默认：本脚本所在目录）")
    ap.add_argument("--uninstall", action="store_true", help="从 PATH 移除并删除 CLBT.cmd")
    ap.add_argument("--no-pause", action="store_true", help="不等待回车（脚本化调用用）")
    ap.add_argument("--no-encoding", action="store_true",
                    help="不自动开启 UTF-8 代码页（默认会开启，解决 bat 中文乱码）")
    args = ap.parse_args()

    say()
    say("  || CLBT 安装器 | Windows 命令行美化工具 ||")
    say()
    if args.uninstall:
        rc = do_uninstall(args.dir)
    else:
        rc = do_install(args.dir, do_encoding=not args.no_encoding)
    _pause_if_interactive(getattr(args, "no_pause", False))
    return rc


if __name__ == "__main__":
    sys.exit(main())
