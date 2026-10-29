#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CLBT 图形界面（tkinter）
========================

对 `terminal-setup.cmd` 的一层图形前端：勾选/滑动就能改外观。所有动作最终都调用
同一个脚本，所以界面和命令行的结果完全一致。

用法：
    python clbt_gui.py                 打开界面
    python clbt_gui.py --selftest      只打印将要执行的命令（不开窗口，自检用）
    python clbt_gui.py --shot out.png  把自己的窗口截图后退出（调试用，需 Pillow）

依赖：Python 3.8+ 自带的 tkinter，不需要第三方库。
"""

import json
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

APP_TITLE = "CLBT · Windows 命令行美化工具"
VERSION = "1.1.1"

# ---- 配色（跟终端黑玻璃一个调子）----
BG = "#0C0C0C"
CARD = "#151515"
CARD2 = "#1F1F1F"
FG = "#D4D4D4"
DIM = "#808080"
LINE = "#2A2A2A"
GREEN = "#3DDC84"
CYAN = "#4EC9D4"
YELLOW = "#E5C07B"
RED = "#E06C75"
BLUE = "#7FB8FF"

UI = ("Microsoft YaHei UI", 10)
UI_S = ("Microsoft YaHei UI", 9)
MONO = ("Cascadia Mono", 9)
MONO_S = ("Cascadia Mono", 8)

# 字体下拉显示短名，内部映射到真实字族（-face）与字重（-font-weight）
FONT_CHOICES = [("斜体", "0xProto Mono Italic"),
                ("等宽", "0xProto Nerd Font Mono"),
                ("标准", "0xProto Nerd Font"),
                ("比例", "0xProto Nerd Font Propo")]
WEIGHT_CHOICES = [("常规", "normal"), ("粗体", "bold")]
# 下拉框里显示中文，传给 terminal-setup.cmd 的仍是英文枚举值
ALIGN_CHOICES = [("居中", "center"), ("顶部", "top"), ("底部", "bottom"),
                 ("左侧", "left"), ("右侧", "right"), ("左上", "topLeft"),
                 ("右上", "topRight"), ("左下", "bottomLeft"), ("右下", "bottomRight")]
STRETCH_CHOICES = [("铺满并裁剪（推荐）", "uniformToFill"), ("拉伸填满（会变形）", "fill"),
                   ("完整显示（留黑边）", "uniform"), ("原始尺寸", "none")]
AA_CHOICES = [("默认（不设置）", ""), ("灰度柔和", "grayscale"),
              ("清晰锐利", "cleartype"), ("像素风", "aliased")]
ADJUST_CHOICES = [("默认（不设置）", ""), ("总是修正", "always"),
                  ("仅索引色", "indexed"), ("不修正", "never")]


def labels(choices):
    return [c[0] for c in choices]


def value_of(choices, label):
    for txt, val in choices:
        if txt == label:
            return val
    return ""


def label_of(choices, value):
    for txt, val in choices:
        if val == value:
            return txt
    return choices[0][0] if value in ("", None) else value


# --------------------------------------------------------------------- 外部环境

def app_dir():
    """exe 所在目录。PyInstaller onefile 下 __file__ 指向临时解包目录（_MEIxxxx），
    必须用 sys.executable，否则永远找不到同目录的 terminal-setup.cmd"""
    if getattr(sys, "frozen", False):
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def find_tool():
    """terminal-setup.cmd：先看自己所在目录（--dir 装到别处时才对得上），
    其次 Program Files，最后 PATH 里的 CLBT"""
    cands = [os.path.join(app_dir(), "terminal-setup.cmd"),
             os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"),
                          "CLBT", "terminal-setup.cmd")]
    clbt = shutil.which("CLBT.cmd") or shutil.which("CLBT")
    if clbt:
        cands.append(os.path.join(os.path.dirname(clbt), "terminal-setup.cmd"))
    for p in cands:
        if p and os.path.isfile(p):
            return p
    return None


def find_installer():
    here = app_dir()
    for p in (os.path.join(here, "install.exe"),
              os.path.join(os.path.expanduser("~"), "Downloads", "install.exe")):
        if os.path.isfile(p):
            return p
    return None


def read_current_settings():
    """读 Windows Terminal 的 settings.json（用于顶部「当前」和界面预填）"""
    la = os.environ.get("LOCALAPPDATA", "")
    cands = [
        os.path.join(la, "Packages", "Microsoft.WindowsTerminal_8wekyb3d8bbwe", "LocalState", "settings.json"),
        os.path.join(la, "Packages", "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe", "LocalState", "settings.json"),
        os.path.join(la, "Microsoft", "Windows Terminal", "settings.json"),
    ]
    for p in cands:
        if not os.path.isfile(p):
            continue
        try:
            with open(p, "r", encoding="utf-8-sig") as f:
                j = json.load(f)
        except Exception:
            continue
        d = (j.get("profiles") or {}).get("defaults") or {}
        font = d.get("font") or {}
        return {
            "path": p,
            "opacity": d.get("opacity"),
            "acrylic": d.get("useAcrylic"),
            "bg": d.get("backgroundImage"),
            "bgOpacity": d.get("backgroundImageOpacity"),
            "bgAlign": d.get("backgroundImageAlignment"),
            "bgStretch": d.get("backgroundImageStretchMode"),
            "face": font.get("face"),
            "weight": font.get("weight"),
            "size": font.get("size"),
            "scheme": d.get("colorScheme"),
            "cellHeight": font.get("cellHeight"),
            "aa": d.get("antialiasingMode"),
            "adjust": d.get("adjustIndistinguishableColors"),
        }
    return None


# --------------------------------------------------------------------- 命令构造

def build_apply_args(st):
    """界面状态 -> terminal-setup.cmd 参数（纯函数，便于自检）"""
    args = ["-linux" if st["style"] == "linux" else "-win",
            "-transparent", str(int(st["transparent"]))]

    if st["style"] == "linux":
        args += ["-acrylic", "on" if st["acrylic"] else "off"]
        if st["font_mode"] == "file" and st["font_file"]:
            args += ["-font", st["font_file"]]
        elif st["face"]:
            args += ["-face", st["face"]]
        if st["weight"]:
            args += ["-font-weight", st["weight"]]

    if not st["bg_enabled"]:
        args += ["-background", "off"]
    elif st["bg_path"]:
        args += ["-background", st["bg_path"],
                 "-bg-opacity", f"{st['bg_opacity']:.2f}",
                 "-bg-align", st["bg_align"],
                 "-bg-stretch", st["bg_stretch"]]

    if st["cell_height"]:
        args += ["-cell-height", st["cell_height"]]
    if st["aa"]:
        args += ["-antialiasing", st["aa"]]
    if st["adjust"]:
        args += ["-adjust-colors", st["adjust"]]
    return args + ["/y"]


# --------------------------------------------------------------------- 预览

PAYLOAD_MARK = "#::PS1::"
FONTS_MARK = "#::FONTS::"
_PAYLOAD_CACHE = {}
# 这些是我们自己传的，预览前先清干净，别把上一次/命令行的残留带进来
_OUR_ENV = ("WT_MODE", "WT_SELF", "WT_PREVIEW_OUT", "WT_PREVIEW_W", "WT_PREVIEW_NOWALL",
            "WT_PREVIEW_TIMING", "WT_STYLE", "WT_TRANSPARENT", "WT_OPACITY", "WT_ACRYLIC",
            "WT_FACE", "WT_FONTWEIGHT", "WT_CELLHEIGHT", "WT_BACKGROUND", "WT_BGOPACITY",
            "WT_BGSTRETCH", "WT_AA", "WT_ADJUST", "WT_FONTFILE")


def powershell_exe():
    """预览要直接跑内嵌载荷；用系统自带的 powershell 5.1（启动最快）"""
    for name in ("powershell.exe", "pwsh.exe"):
        p = shutil.which(name)
        if p:
            return p
    return None


def extract_payload(tool_path):
    """从 terminal-setup.cmd 里切出内嵌的 PowerShell 载荷（和 cmd 里的切法一致）"""
    st = os.stat(tool_path)
    key = (tool_path, st.st_mtime_ns, st.st_size)
    if key in _PAYLOAD_CACHE:
        return _PAYLOAD_CACHE[key]

    def head(limit):
        with open(tool_path, "rb") as f:
            return f.read(limit).decode("utf-8", "replace")

    # 载荷紧跟在批处理区（前 ~300 行）后面，先只读开头 2MB，很快
    raw = head(min(2 * 1024 * 1024, st.st_size))
    i = raw.rfind(PAYLOAD_MARK)
    if i < 0:                      # 结构变了就退回整文件
        raw = head(st.st_size)
        i = raw.rfind(PAYLOAD_MARK)
    if i < 0:
        raise RuntimeError("找不到载荷标记 " + PAYLOAD_MARK)
    j = raw.find(FONTS_MARK, i)
    code = raw[i + len(PAYLOAD_MARK):] if j < 0 else raw[i + len(PAYLOAD_MARK):j]
    if len(code) < 4096 or "Render-Preview" not in code:
        # 旧版工具里没有预览渲染器，硬跑会掉进交互菜单卡住，直接放弃这条路
        raise RuntimeError("这个 terminal-setup.cmd 还不支持预览（版本太旧？）")
    _PAYLOAD_CACHE.clear()
    _PAYLOAD_CACHE[key] = code
    return code


def ttf_family(path):
    """从 .ttf/.otf 的 name 表里读出字族名；读不到就返回空串（预览用）"""
    try:
        with open(path, "rb") as f:
            data = f.read()
        if len(data) < 12:
            return ""
        num = int.from_bytes(data[4:6], "big")
        name_off = None
        for i in range(min(num, 512)):
            rec = 12 + i * 16
            if data[rec:rec + 4] == b"name":
                name_off = int.from_bytes(data[rec + 8:rec + 12], "big")
                break
        if name_off is None:
            return ""
        count = int.from_bytes(data[name_off + 2:name_off + 4], "big")
        str_off = name_off + int.from_bytes(data[name_off + 4:name_off + 6], "big")
        best = ""
        for i in range(min(count, 512)):
            r = name_off + 6 + i * 12
            pid = int.from_bytes(data[r:r + 2], "big")
            nid = int.from_bytes(data[r + 6:r + 8], "big")
            length = int.from_bytes(data[r + 8:r + 10], "big")
            soff = int.from_bytes(data[r + 10:r + 12], "big")
            if nid not in (1, 16) or length <= 0:
                continue
            raw = data[str_off + soff:str_off + soff + length]
            txt = raw.decode("utf-16-be" if pid in (0, 3) else "latin-1").strip()
            if not txt:
                continue
            if nid == 16 and pid == 3:
                return txt
            if not best:
                best = txt
        return best
    except Exception:  # noqa: BLE001
        return ""


def preview_env(st, out_path, width=520, height=0):
    """界面状态 -> 预览用的环境变量（Render-Preview 认的就是这套 WT_*）"""
    env = dict(os.environ)
    for k in _OUR_ENV:
        env.pop(k, None)
    env["WT_MODE"] = "preview"
    env["WT_PREVIEW_OUT"] = out_path
    env["WT_PREVIEW_W"] = str(int(width))
    if height:
        env["WT_PREVIEW_H"] = str(int(height))
    env["WT_STYLE"] = "win" if st["style"] == "win" else "linux"
    env["WT_TRANSPARENT"] = str(int(st["transparent"]))
    if env["WT_STYLE"] == "linux":
        # 亚克力只有仿 Linux 那套才可调，Windows 原生模式让脚本自己决定
        env["WT_ACRYLIC"] = "on" if st["acrylic"] else "off"
        face = st.get("face") or ""
        if st.get("font_mode") == "file" and st.get("font_file"):
            face = ttf_family(st["font_file"]) or face
        if face:
            env["WT_FACE"] = face
        if st.get("weight") == "bold":
            env["WT_FONTWEIGHT"] = "bold"
    if st.get("cell_height"):
        env["WT_CELLHEIGHT"] = str(st["cell_height"])
    if not st.get("bg_enabled"):
        env["WT_BACKGROUND"] = "off"
    elif st.get("bg_path"):
        env["WT_BACKGROUND"] = st["bg_path"]
        env["WT_BGOPACITY"] = "%.2f" % st["bg_opacity"]
        if st.get("bg_stretch"):
            env["WT_BGSTRETCH"] = st["bg_stretch"]
    return env


def render_preview_direct(tool_path, st, out_path, width=520, height=0):
    """直接跑内嵌载荷出图：绕开 cmd 逐行扫描 33MB 文件的 3 秒开销。
    返回 (rc, 秒数)；返回 (None, 0) 表示这条路用不了，调用方退回走 -preview。"""
    ps = powershell_exe()
    if not ps:
        return None, 0.0
    try:
        code = extract_payload(tool_path)
    except Exception:  # noqa: BLE001
        return None, 0.0
    tmp = os.path.join(tempfile.gettempdir(), "clbt_prev_%d.ps1" % os.getpid())
    t0 = time.time()
    try:
        # newline="" 保持载荷里的 CRLF 原样；utf-8-sig 是因为载荷里有中文注释
        with open(tmp, "w", encoding="utf-8-sig", newline="") as f:
            f.write(code)
        p = subprocess.run(
            [ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", tmp],
            capture_output=True, cwd=os.path.dirname(tool_path) or None,
            creationflags=0x08000000, env=preview_env(st, out_path, width, height), timeout=60)
    finally:
        try:
            os.remove(tmp)
        except Exception:  # noqa: BLE001
            pass
    dt = time.time() - t0
    if os.path.isfile(out_path):
        return 0, dt
    return (p.returncode or 1), dt


# --------------------------------------------------------------------- 界面

def set_dpi_aware():
    """让 Tk 的坐标 == 物理像素；否则在 125%/150% 缩放下窗口会被系统放大，
    截图和高 DPI 屏上的显示都会错位。"""
    try:
        import ctypes
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        try:
            import ctypes
            ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


def window_scale(root):
    """当前显示器缩放（1.0 = 100%）。
    优先问 GetDpiForMonitor（窗口还没显示时也能拿到正确值），
    因为 per-monitor 感知的进程里 Tk 从 GetDeviceCaps 拿到的始终是 96。"""
    try:
        import ctypes
        from ctypes import wintypes
        MONITOR_DEFAULTTOPRIMARY = 1
        mon = ctypes.windll.user32.MonitorFromPoint(wintypes.POINT(0, 0), MONITOR_DEFAULTTOPRIMARY)
        dx, dy = ctypes.c_uint(), ctypes.c_uint()
        ctypes.windll.shcore.GetDpiForMonitor(mon, 0, ctypes.byref(dx), ctypes.byref(dy))
        if dx.value:
            return dx.value / 96.0, float(dx.value)
    except Exception:
        pass
    try:
        import ctypes
        hwnd = ctypes.windll.user32.GetParent(root.winfo_id()) or root.winfo_id()
        dpi = ctypes.windll.user32.GetDpiForWindow(hwnd)
        if dpi and dpi != 96:
            return dpi / 96.0, float(dpi)
    except Exception:
        pass
    try:
        dpi = root.winfo_fpixels("1i")
        return dpi / 96.0, dpi
    except Exception:
        return 1.0, 96.0


class App:
    def __init__(self, root):
        self.root = root
        self.tool = find_tool()
        self.q = queue.Queue()
        self.busy = False
        self.action_buttons = []
        self.dirty = False        # 有未保存的改动？
        self._loading = True      # 预填期间不要标脏

        root.title(f"{APP_TITLE}  v{VERSION}")
        root.configure(bg=BG)
        self.dpi, dpi_px = window_scale(root)
        try:
            root.tk.call("tk", "scaling", dpi_px / 72.0)
        except Exception:
            pass
        root.geometry(f"{int(1060 * self.dpi)}x{int(800 * self.dpi)}")
        root.minsize(int(1000 * self.dpi), int(740 * self.dpi))

        self._build_style()
        self._build_ui()
        self._load_defaults()
        self._refresh_status()
        # 按内容自适应窗口大小，避免控件被裁掉；再给自己的下限
        self.root.update_idletasks()
        w = max(int(1060 * self.dpi), self.root.winfo_reqwidth() + 10)
        h = max(int(800 * self.dpi), self.root.winfo_reqheight() + 10)
        sw, sh = self.root.winfo_screenwidth(), self.root.winfo_screenheight()
        self.root.geometry(f"{min(w, sw - 40)}x{min(h, sh - 80)}")
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)
        self.root.after(60, self._drain)
        self.root.after(120, self._dark_titlebar)
        if not self.tool:
            self.log("找不到 terminal-setup.cmd —— 请先运行 install.exe 安装。", "err")

    # ---------------- 样式
    def _build_style(self):
        s = ttk.Style(self.root)
        try:
            s.theme_use("clam")
        except Exception:
            pass
        s.configure("TCombobox", fieldbackground=CARD2, background=CARD2, foreground=FG,
                    arrowcolor=FG, bordercolor=LINE, lightcolor=CARD2, darkcolor=CARD2,
                    padding=3)
        s.map("TCombobox", fieldbackground=[("readonly", CARD2)], foreground=[("readonly", FG)],
              background=[("readonly", CARD2)], arrowcolor=[("disabled", LINE)])
        s.configure("TSpinbox", fieldbackground=CARD2, background=CARD2, foreground=FG,
                    arrowcolor=FG, bordercolor=LINE, insertcolor=FG, padding=2)
        self.root.option_add("*TCombobox*Listbox.background", CARD2)
        self.root.option_add("*TCombobox*Listbox.foreground", FG)
        self.root.option_add("*TCombobox*Listbox.selectBackground", "#264A36")
        self.root.option_add("*TCombobox*Listbox.selectForeground", GREEN)

    def _dark_titlebar(self):
        try:
            import ctypes
            hwnd = ctypes.windll.user32.GetParent(self.root.winfo_id())
            on = ctypes.c_int(1)
            ctypes.windll.dwmapi.DwmSetWindowAttribute(hwnd, 20, ctypes.byref(on), 4)
        except Exception:
            pass

    # ---------------- 小组件
    def _card(self, parent, title):
        outer = tk.Frame(parent, bg=CARD, highlightbackground=LINE, highlightthickness=1)
        tk.Label(outer, text=title, bg=CARD, fg=GREEN, font=UI_S, anchor="w").pack(
            fill="x", padx=10, pady=(7, 1))
        body = tk.Frame(outer, bg=CARD)
        body.pack(fill="both", expand=True, padx=10, pady=(0, 8))
        return outer, body

    def _btn(self, parent, text, cmd, bg=CARD2, fg=FG, font=UI_S, **kw):
        padx = kw.pop("padx", 10)
        pady = kw.pop("pady", 5)
        b = tk.Button(parent, text=text, command=cmd, bg=bg, fg=fg, font=font,
                      activebackground="#2C2C2C", activeforeground=fg,
                      disabledforeground="#5A5A5A", relief="flat", bd=0,
                      padx=padx, pady=pady, cursor="hand2", **kw)
        b.bind("<Enter>", lambda e: b.configure(bg="#2C2C2C") if str(b["state"]) != "disabled" else None)
        b.bind("<Leave>", lambda e: b.configure(bg=bg))
        return b

    def _slider(self, parent, lo, hi, init, res=1, length=180, cb=None):
        s = tk.Scale(parent, from_=lo, to=hi, resolution=res, orient="horizontal",
                     length=length, bg=CARD, fg=FG, troughcolor="#262626",
                     highlightthickness=0, bd=0, sliderrelief="flat",
                     activebackground=GREEN, font=MONO_S, showvalue=False,
                     command=cb or (lambda v: None))
        # 必须显式设初值：tk.Scale 不认构造参数里的"初值"，默认停在 from_ 那一端，
        # 结果浓淡会变成 0.05（图几乎透明）、透明度会变成 0（窗口不透明）
        s.set(init)
        return s

    def _chk(self, parent, text, var, cmd=None):
        return tk.Checkbutton(parent, text=text, variable=var, bg=CARD, fg=FG, selectcolor=CARD,
                              activebackground=CARD, activeforeground=GREEN, font=UI_S,
                              bd=0, highlightthickness=0, anchor="w", command=cmd)

    # ---------------- 布局
    def _build_ui(self):
        """两列固定布局：左列宽度固定，右列吃掉剩余空间，任何窗口尺寸都不会溢出"""
        root = self.root
        root.grid_rowconfigure(1, weight=1)
        root.grid_columnconfigure(0, weight=1)

        # ---- 顶栏
        head = tk.Frame(root, bg=BG)
        head.grid(row=0, column=0, sticky="ew", padx=14, pady=(12, 8))
        tk.Label(head, text="▌CLBT", bg=BG, fg=GREEN,
                 font=("Microsoft YaHei UI", 15, "bold")).pack(side="left")
        tk.Label(head, text="   Windows 命令行美化工具 · 图形界面", bg=BG, fg=DIM,
                 font=UI).pack(side="left", pady=(5, 0))
        self.lbl_tool = tk.Label(head, text=self.tool or "未找到工具", bg=BG, fg=DIM, font=MONO_S)
        self.lbl_tool.pack(side="right", pady=(5, 0))

        # ---- 主体两列
        body = tk.Frame(root, bg=BG)
        body.grid(row=1, column=0, sticky="nsew", padx=14)
        body.grid_rowconfigure(0, weight=1)
        body.grid_columnconfigure(0, weight=0, minsize=470)
        body.grid_columnconfigure(1, weight=1)

        left = tk.Frame(body, bg=BG)
        left.grid(row=0, column=0, sticky="nsew", padx=(0, 8))
        right = tk.Frame(body, bg=BG)
        right.grid(row=0, column=1, sticky="nsew", padx=(8, 0))
        right.grid_rowconfigure(2, weight=1)
        right.grid_columnconfigure(0, weight=1)

        # ================= 左列：风格 / 透明度 / 字体 / 细节
        c, b = self._card(left, "风格")
        c.pack(fill="x", pady=(0, 8))
        self.var_style = tk.StringVar(value="linux")
        for val, txt, fg in (("linux", "仿 Linux（亚克力 + bash 提示符）", GREEN),
                             ("win", "Windows 原生（默认配色/提示符）", FG)):
            tk.Radiobutton(b, text=txt, value=val, variable=self.var_style, bg=CARD, fg=fg,
                           selectcolor=CARD, activebackground=CARD, activeforeground=fg,
                           font=UI_S, anchor="w", bd=0, highlightthickness=0,
                           command=self._on_style).pack(fill="x")
        self.var_enc = tk.BooleanVar(value=True)
        self.var_adapt = tk.BooleanVar(value=False)
        tk.Frame(b, bg=LINE, height=1).pack(fill="x", pady=5)
        self._chk(b, "cmd 标签 UTF-8 启动（修 bat 乱码）", self.var_enc, self._on_enc).pack(fill="x")
        self._chk(b, "自适应前景色（按背景明暗切深浅）", self.var_adapt, self._on_adapt).pack(fill="x")
        self.var_acrylic = tk.BooleanVar(value=True)
        self._chk(b, "亚克力磨砂（关掉才是真透明）", self.var_acrylic, self._on_acrylic).pack(fill="x")

        c, b = self._card(left, "透明度 / 不透明度")
        c.pack(fill="x", pady=(0, 8))
        self.var_transp = tk.IntVar(value=64)
        self.lbl_transp = tk.Label(b, text="透明度 64%  →  不透明度 36%", bg=CARD, fg=FG,
                                   font=UI_S, anchor="w")
        self.lbl_transp.pack(fill="x")
        self.scale_transp = self._slider(b, 0, 100, 64, length=420, cb=lambda v: self._on_transp())
        self.scale_transp.pack(fill="x", pady=(4, 2))
        tk.Label(b, text="0 = 完全不透明 · 100 = 全透（等同 CLBT -transparent 的数值）",
                 bg=CARD, fg=DIM, font=MONO_S, anchor="w").pack(fill="x")
        tk.Label(b, text="改的是 Windows Terminal 窗口，不是这个界面；改完点左下角「保存设置」才生效",
                 bg=CARD, fg="#E5C07B", font=MONO_S, anchor="w", wraplength=430,
                 justify="left").pack(fill="x")

        c, b = self._card(left, "字体（仿 Linux 风格生效）")
        c.pack(fill="x", pady=(0, 8))
        self.var_font_mode = tk.StringVar(value="face")
        self.var_face = tk.StringVar(value=FONT_CHOICES[0][0])
        self.var_weight = tk.StringVar(value=WEIGHT_CHOICES[0][0])
        self.var_font_file = tk.StringVar(value="")
        line = tk.Frame(b, bg=CARD)
        line.pack(fill="x")
        tk.Label(line, text="字形", bg=CARD, fg=DIM, font=UI_S).pack(side="left")
        self.cmb_face = ttk.Combobox(line, textvariable=self.var_face, values=labels(FONT_CHOICES),
                                     width=6, state="readonly", font=MONO_S)
        self.cmb_face.pack(side="left", padx=(6, 10))
        self.cmb_face.bind("<<ComboboxSelected>>", lambda e: self.var_font_mode.set("face"))
        tk.Label(line, text="字重", bg=CARD, fg=DIM, font=UI_S).pack(side="left")
        self.cmb_weight = ttk.Combobox(line, textvariable=self.var_weight, values=labels(WEIGHT_CHOICES),
                                       width=6, state="readonly", font=MONO_S)
        self.cmb_weight.pack(side="left", padx=(6, 0))
        self._btn(line, "装内置字体", self._install_fonts, padx=8).pack(side="right")
        line2 = tk.Frame(b, bg=CARD)
        line2.pack(fill="x", pady=(6, 0))
        self.entry_font = tk.Entry(line2, textvariable=self.var_font_file, bg=CARD2, fg=FG,
                                   font=MONO_S, insertbackground=FG, relief="flat", bd=4, width=1)
        self.entry_font.pack(side="left", fill="x", expand=True)
        self.entry_font.bind("<FocusIn>", lambda e: self.var_font_mode.set("file"))
        self._btn(line2, "浏览", self._pick_font, padx=8).pack(side="left", padx=(8, 0))
        tk.Label(b, text="字形走 -face，字重走 -font-weight，自定义文件走 -font", bg=CARD, fg=DIM,
                 font=MONO_S, anchor="w").pack(fill="x", pady=(4, 0))

        c, b = self._card(left, "细节")
        c.pack(fill="x")
        g = tk.Frame(b, bg=CARD)
        g.pack(fill="x")
        tk.Label(g, text="行高", bg=CARD, fg=DIM, font=UI_S).grid(row=0, column=0, sticky="w")
        self.var_cellh = tk.StringVar(value="")
        ttk.Spinbox(g, textvariable=self.var_cellh, values=("", "1.0", "1.1", "1.2", "1.3", "1.5"),
                    width=5, font=MONO_S).grid(row=0, column=1, sticky="w", padx=(10, 0))
        tk.Label(g, text="留空 = 不设置", bg=CARD, fg=DIM, font=MONO_S).grid(
            row=0, column=2, sticky="w", padx=8)
        tk.Label(g, text="抗锯齿", bg=CARD, fg=DIM, font=UI_S).grid(row=1, column=0, sticky="w", pady=(6, 0))
        self.var_aa = tk.StringVar(value=AA_CHOICES[0][0])
        ttk.Combobox(g, textvariable=self.var_aa, values=labels(AA_CHOICES), width=18, state="readonly",
                     font=MONO_S).grid(row=1, column=1, columnspan=2, sticky="w", padx=(10, 0), pady=(6, 0))
        tk.Label(g, text="颜色修正", bg=CARD, fg=DIM, font=UI_S).grid(row=2, column=0, sticky="w", pady=(6, 0))
        self.var_adjust = tk.StringVar(value=ADJUST_CHOICES[0][0])
        ttk.Combobox(g, textvariable=self.var_adjust, values=labels(ADJUST_CHOICES), width=18, state="readonly",
                     font=MONO_S).grid(row=2, column=1, columnspan=2, sticky="w", padx=(10, 0), pady=(6, 0))

        # ================= 右列：背景图 / 当前设置 / 输出
        c, b = self._card(right, "背景图")
        c.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        self.var_bg_on = tk.BooleanVar(value=False)
        self.var_bg = tk.StringVar(value="")
        line = tk.Frame(b, bg=CARD)
        line.pack(fill="x")
        self._chk(line, "启用", self.var_bg_on, self._on_bg_toggle).pack(side="left")
        self.entry_bg = tk.Entry(line, textvariable=self.var_bg, bg=CARD2, fg=FG, font=MONO_S,
                                 insertbackground=FG, relief="flat", bd=4, width=1)
        self.entry_bg.pack(side="left", fill="x", expand=True, padx=6)
        self._btn(line, "浏览", self._pick_bg, padx=8).pack(side="left")

        self.lbl_bg_hint = tk.Label(b, text="", bg=CARD, fg=DIM, font=MONO_S,
                                    anchor="w", wraplength=430, justify="left")
        self.lbl_bg_hint.pack(fill="x", pady=(4, 0))

        g = tk.Frame(b, bg=CARD)
        g.pack(fill="x", pady=(6, 0))
        self.var_bg_op = tk.DoubleVar(value=0.55)
        tk.Label(g, text="浓淡", bg=CARD, fg=DIM, font=UI_S).grid(row=0, column=0, sticky="w")
        self.scale_bgop = self._slider(g, 0.05, 0.95, 0.55, res=0.01, length=120,
                                       cb=lambda v: self._on_bgop())
        self.scale_bgop.grid(row=0, column=1, sticky="w", padx=6)
        self.lbl_bgop = tk.Label(g, text="0.55", bg=CARD, fg=FG, font=MONO_S, width=4, anchor="w")
        self.lbl_bgop.grid(row=0, column=2, sticky="w")

        g2 = tk.Frame(b, bg=CARD)
        g2.pack(fill="x", pady=(6, 0))
        tk.Label(g2, text="对齐", bg=CARD, fg=DIM, font=UI_S).grid(row=0, column=0, sticky="w")
        self.var_align = tk.StringVar(value=ALIGN_CHOICES[0][0])
        ttk.Combobox(g2, textvariable=self.var_align, values=labels(ALIGN_CHOICES), width=10,
                     state="readonly", font=MONO_S).grid(row=0, column=1, sticky="w", padx=(10, 12))
        tk.Label(g2, text="拉伸", bg=CARD, fg=DIM, font=UI_S).grid(row=0, column=2, sticky="w")
        self.var_stretch = tk.StringVar(value=STRETCH_CHOICES[0][0])
        ttk.Combobox(g2, textvariable=self.var_stretch, values=labels(STRETCH_CHOICES), width=17,
                     state="readonly", font=MONO_S).grid(row=0, column=3, sticky="w", padx=(10, 0))

        c, b = self._card(right, "预览（还没保存的改动也能先看到）")
        c.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        # 图是 520x292，居中显示；底色用卡片色 + 细边，两边不会出现硬邦邦的黑边
        self.lbl_preview = tk.Label(b, text="正在生成预览…", bg=CARD2, fg=DIM,
                                    font=MONO_S, width=52, height=13,
                                    highlightthickness=1, highlightbackground=LINE)
        self.lbl_preview.pack(fill="x")
        self.lbl_prev_info = tk.Label(b, text="", bg=CARD, fg=DIM, font=MONO_S, anchor="w")
        self.lbl_prev_info.pack(fill="x", pady=(4, 0))
        self.lbl_cur = tk.Label(b, text="", bg=CARD, fg=DIM, font=MONO_S, anchor="w",
                                wraplength=500, justify="left")
        self.lbl_cur.pack(fill="x")
        self._preview_img = None
        self._preview_job = None
        self._preview_seq = 0

        c, b = self._card(right, "输出")
        c.grid(row=2, column=0, sticky="nsew")
        self.log_text = tk.Text(b, bg="#080808", fg=FG, font=MONO_S, relief="flat",
                                insertbackground=FG, wrap="word", height=8, width=1, bd=0,
                                padx=6, pady=4)
        sb = tk.Scrollbar(b, command=self.log_text.yview, bg=CARD2, troughcolor=CARD,
                          activebackground=LINE, bd=0, width=10)
        self.log_text.configure(yscrollcommand=sb.set)
        self.log_text.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")
        for tag, color in (("ok", GREEN), ("warn", YELLOW), ("err", RED),
                           ("dim", DIM), ("cmd", CYAN), ("title", BLUE)):
            self.log_text.tag_configure(tag, foreground=color)
        self.log_text.configure(state="disabled")

        # ---- 底部按钮：保存做成整条最扎眼的那一个
        acts = tk.Frame(root, bg=BG)
        acts.grid(row=2, column=0, sticky="ew", padx=14, pady=(10, 12))

        self.btn_apply = tk.Button(
            acts, text="💾  保存设置", command=self._apply,
            bg=GREEN, fg="#06210F", activebackground="#6BF2A8", activeforeground="#06210F",
            font=("Microsoft YaHei UI", 11, "bold"), relief="flat", bd=0,
            padx=22, pady=9, cursor="hand2")
        self.btn_apply.pack(side="left")
        self.action_buttons.append(self.btn_apply)

        self.lbl_dirty = tk.Label(acts, text="", bg=BG, fg=YELLOW,
                                  font=("Microsoft YaHei UI", 10, "bold"))
        self.lbl_dirty.pack(side="left", padx=(14, 0))
        for txt, fn in (("恢复 Windows 原生", self._to_win),
                        ("撤回外观修改", self._uninstall),
                        ("移除 cmd 提示符", self._undo_cmd),
                        ("卸载命令行入口", self._uninstall_cmd)):
            btn = self._btn(acts, txt, fn)
            btn.pack(side="left", padx=(8, 0))
            self.action_buttons.append(btn)
        diag = self._btn(acts, "环境诊断", self._diagnose, bg=CARD, fg=CYAN)
        diag.pack(side="right", padx=(0, 8))
        self._btn(acts, "清空日志", self._clear_log, bg=CARD, fg=DIM).pack(side="right")

        # 任何控件一改就提示「有未保存的改动」
        for var in (self.var_style, self.var_transp, self.var_enc, self.var_adapt,
                    self.var_acrylic, self.var_face, self.var_weight, self.var_font_file,
                    self.var_cellh, self.var_aa, self.var_adjust, self.var_bg_on,
                    self.var_bg, self.var_bg_op, self.var_align, self.var_stretch):
            try:
                var.trace_add("write", self._mark_dirty)
            except Exception:
                pass

    # ---------------- 预览
    def _schedule_preview(self, delay=350):
        if not hasattr(self, "_preview_job"):
            return
        try:
            if self._preview_job:
                self.root.after_cancel(self._preview_job)
        except Exception:
            pass
        self._preview_job = self.root.after(delay, self._render_preview)

    def _render_preview(self):
        self._preview_job = None
        if not self.tool:
            self.lbl_preview.configure(text="找不到 terminal-setup.cmd", image="")
            return
        self._preview_seq += 1
        seq = self._preview_seq
        out = os.path.join(tempfile.gettempdir(), f"clbt_preview_{os.getpid()}.png")
        try:
            if os.path.isfile(out):
                os.remove(out)
        except Exception:
            pass
        st = self._state()
        # 按预览卡的实际宽度出图，铺满卡片（高度固定 292，比例像真实终端）
        try:
            pw = int(self.lbl_preview.winfo_width()) - 4
        except Exception:  # noqa: BLE001
            pw = 520
        if pw < 320:
            pw = 520
        ph = 292
        self.lbl_prev_info.configure(text="正在生成预览 . . .")

        def work():
            rc, dt = render_preview_direct(self.tool, st, out, pw, ph)
            if rc is None:      # 直跑载荷不可用：退回走命令行（慢一点，但一定有图）
                t0 = time.time()
                try:
                    p = subprocess.run([self.tool, "-preview", out] + build_apply_args(st),
                                       capture_output=True, cwd=os.path.dirname(self.tool),
                                       creationflags=0x08000000, timeout=180)
                    rc = 0 if os.path.isfile(out) else (p.returncode or 1)
                except Exception as e:  # noqa: BLE001
                    rc = -1
                    self.q.put(("line", f"预览失败: {e}"))
                dt = time.time() - t0
            self.q.put(("preview", (seq, rc, out, st, dt)))

        threading.Thread(target=work, daemon=True).start()

    def _apply_preview(self, payload):
        seq, rc, path, st, dt = payload
        if seq != self._preview_seq:
            return              # 有更新的预览在生成，丢掉这次结果
        if rc == 0 and os.path.isfile(path):
            try:
                img = tk.PhotoImage(file=path)
                self._preview_img = img
                # width/height 是"字符数"，不归零的话图片会被裁成一条细缝
                self.lbl_preview.configure(image=img, text="", width=0, height=0)
            except Exception as e:  # noqa: BLE001
                self.lbl_preview.configure(text=f"预览加载失败：{e}", image="",
                                           width=52, height=13)
        else:
            self.lbl_preview.configure(text=f"预览生成失败（rc={rc}）\n{path}", image="",
                                       width=52, height=13)
        bg = "无"
        if st["bg_enabled"]:
            bg = "有" if st["bg_path"] else "未选"
        style = "仿 Linux" if st["style"] == "linux" else "Windows 原生"
        acr = "开" if st["acrylic"] else "关"
        face = self.var_face.get() if st["style"] == "linux" else "系统默认"
        self.lbl_prev_info.configure(
            text=f"{style} · 不透明度 {100 - st['transparent']}% · 亚克力{acr} · "
                 f"背景图 {bg}（浓淡 {st['bg_opacity']:.2f}）· {face} / {self.var_weight.get()}"
                 f"　·　{dt:.1f}s")

    # ---------------- 未保存状态
    def _mark_dirty(self, *_args):
        if getattr(self, "_loading", False):
            return
        if self.dirty:
            self._schedule_preview()
            return
        self.dirty = True
        self._refresh_dirty_ui()
        self._schedule_preview()

    def _mark_clean(self, flash=False):
        self.dirty = False
        self._refresh_dirty_ui()
        if flash:
            self.lbl_dirty.configure(text="✓ 已保存", fg=GREEN)
            self.root.after(3000, lambda: self.lbl_dirty.configure(text="") if not self.dirty else None)

    def _refresh_dirty_ui(self):
        try:
            if self.dirty:
                self.lbl_dirty.configure(text='● 有未保存的改动 —— 点左边「保存设置」', fg=YELLOW)
                self.root.title(f"{APP_TITLE}  v{VERSION}  *")
                self.btn_apply.configure(bg="#FFC857", fg="#3A2A00")
            else:
                self.lbl_dirty.configure(text="")
                self.root.title(f"{APP_TITLE}  v{VERSION}")
                self.btn_apply.configure(bg=GREEN, fg="#06210F")
        except Exception:
            pass

    def _on_close(self):
        if getattr(self, "dirty", False):
            if not messagebox.askyesno(APP_TITLE,
                                       "有未保存的改动。\n\n点「保存设置」才会写进终端；现在退出会丢掉这些改动。\n仍然退出吗？"):
                return
        self.root.destroy()

    # ---------------- 预填 / 状态
    def _load_defaults(self):
        cur = read_current_settings()
        self.current = cur
        if not cur:
            return
        op = cur.get("opacity")
        if isinstance(op, int) and 0 <= op <= 100:
            self.scale_transp.set(100 - op)
        face = cur.get("face")
        if face:
            self.var_face.set(label_of(FONT_CHOICES, face))
        if (cur.get("weight") or "").lower() == "bold":
            self.var_weight.set(WEIGHT_CHOICES[1][0])
        bg = cur.get("bg")
        if bg:
            # 文件可能被清理掉了：照样显示路径并保持勾选，避免下一按「应用」就把背景图静默删掉
            self.var_bg.set(bg)
            self.var_bg_on.set(True)
            self.bg_missing = not os.path.isfile(bg)
        else:
            self.bg_missing = False
        bo = cur.get("bgOpacity")
        if isinstance(bo, (int, float)) and 0.01 <= float(bo) <= 1.0:
            self.scale_bgop.set(float(bo))
        if cur.get("bgAlign"):
            self.var_align.set(label_of(ALIGN_CHOICES, cur["bgAlign"]))
        if cur.get("bgStretch"):
            self.var_stretch.set(label_of(STRETCH_CHOICES, cur["bgStretch"]))
        if cur.get("cellHeight"):
            self.var_cellh.set(str(cur["cellHeight"]))
        if cur.get("aa"):
            self.var_aa.set(label_of(AA_CHOICES, cur["aa"]))
        if cur.get("adjust"):
            self.var_adjust.set(label_of(ADJUST_CHOICES, cur["adjust"]))
        if cur.get("acrylic") is not None:
            self.var_acrylic.set(bool(cur["acrylic"]))
        self._on_transp()
        self._on_bgop()
        self._on_bg_toggle()
        self._bg_hint()
        self._loading = False
        self._mark_clean()
        self._schedule_preview(200)

    def _refresh_status(self):
        cur = read_current_settings()
        self.current = cur
        if not cur:
            self.lbl_cur.configure(text="找不到 Windows Terminal 的 settings.json")
            return
        op = cur.get("opacity")
        bg = cur.get("bg")
        parts = [
            f"已保存：不透明度 {op}%" if isinstance(op, int) else "已保存：不透明度（默认）",
            "亚克力开" if cur.get("acrylic") else "亚克力关",
            cur.get("scheme") or "默认配色",
            (cur.get("face") or "系统字体") + (f" {cur.get('size')}pt" if cur.get("size") else ""),
            os.path.basename(bg) if bg else "无背景图",
        ]
        self.lbl_cur.configure(text=" · ".join(parts))

    # ---------------- 回调
    def _transp_text(self):
        t = int(float(self.var_transp.get()))
        return f"透明度 {t}%  →  不透明度 {100 - t}%"

    def _on_transp(self):
        t = int(float(self.scale_transp.get()))
        self.var_transp.set(t)
        txt = f"透明度 {t}%  →  不透明度 {100 - t}%"
        txt += "    亚克力：磨砂玻璃" if self.var_acrylic.get() else "    亚克力：关（真透明）"
        self.lbl_transp.configure(text=txt)

    def _on_bgop(self):
        v = float(self.scale_bgop.get())
        self.var_bg_op.set(v)
        self.lbl_bgop.configure(text=f"{v:.2f}")

    def _bg_hint(self):
        path = (self.var_bg.get() or "").strip().lower()
        animated = path.endswith(".gif")
        if getattr(self, "bg_missing", False) and self.var_bg_on.get():
            self.lbl_bg_hint.configure(
                text="⚠ settings.json 里的背景图文件已不存在；取消勾选「启用」才能移除它",
                fg=YELLOW)
        elif animated and self.var_bg_on.get():
            self.lbl_bg_hint.configure(
                text="动态壁纸：.gif 会按原帧率循环播放（Terminal 自己播，不额外占进程）",
                fg=GREEN)
        else:
            self.lbl_bg_hint.configure(
                text="支持 PNG / JPG / GIF（动图会动）/ BMP；图片会被复制到 %LOCALAPPDATA%\\WindowsCommandLineBeautify",
                fg=DIM)

    def _on_bg_toggle(self):
        on = bool(self.var_bg_on.get())
        st = "normal" if on else "disabled"
        self.entry_bg.configure(state=st, bg=CARD2 if on else "#101010", fg=FG if on else DIM)
        self.scale_bgop.configure(state=st)
        if hasattr(self, "lbl_bg_hint"):
            self._bg_hint()

    def _on_acrylic(self):
        on = bool(self.var_acrylic.get())
        self.lbl_transp.configure(
            text=self._transp_text() + ("    亚克力：磨砂玻璃" if on else "    亚克力：关（真透明）"))

    def _on_style(self):
        linux = self.var_style.get() == "linux"
        self.cmb_face.configure(state="readonly" if linux else "disabled")
        self.entry_font.configure(state="normal" if linux else "disabled")

    def _pick_bg(self):
        p = filedialog.askopenfilename(title="选择背景图片",
                                       filetypes=[("图片", "*.png *.jpg *.jpeg *.gif *.bmp"),
                                                  ("全部", "*.*")])
        if p:
            self.var_bg.set(p)
            self.var_bg_on.set(True)
            self._on_bg_toggle()

    def _pick_font(self):
        p = filedialog.askopenfilename(title="选择字体文件",
                                       filetypes=[("字体", "*.ttf *.otf *.ttc"), ("全部", "*.*")])
        if p:
            self.var_font_file.set(p)
            self.var_font_mode.set("file")

    # ---------------- 执行
    def _state(self):
        return {
            "style": self.var_style.get(),
            "transparent": int(self.var_transp.get()),
            "acrylic": bool(self.var_acrylic.get()),
            "bg_enabled": bool(self.var_bg_on.get()),
            "bg_path": self.var_bg.get().strip(),
            "bg_opacity": float(self.var_bg_op.get()),
            "bg_align": value_of(ALIGN_CHOICES, self.var_align.get()),
            "bg_stretch": value_of(STRETCH_CHOICES, self.var_stretch.get()),
            "font_mode": self.var_font_mode.get(),
            "face": value_of(FONT_CHOICES, self.var_face.get()),
            "weight": value_of(WEIGHT_CHOICES, self.var_weight.get()),
            "font_file": self.var_font_file.get().strip(),
            "cell_height": self.var_cellh.get().strip(),
            "aa": value_of(AA_CHOICES, self.var_aa.get()),
            "adjust": value_of(ADJUST_CHOICES, self.var_adjust.get()),
        }

    def _set_busy(self, busy):
        self.busy = busy
        state = "disabled" if busy else "normal"
        for b in self.action_buttons:
            b.configure(state=state)

    def _run(self, args, title, clears_dirty=False):
        if self.busy:
            return
        if not self.tool:
            messagebox.showerror(APP_TITLE, "找不到 terminal-setup.cmd，请先运行 install.exe。")
            return
        self._pending_clears_dirty = clears_dirty
        self._set_busy(True)
        self.log("", None)
        self.log(f"$ CLBT {' '.join(args)}", "cmd")
        self.log(f"  （{title}）", "dim")

        def work():
            try:
                p = subprocess.Popen([self.tool] + args, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, cwd=os.path.dirname(self.tool),
                                     creationflags=0x08000000)
                for raw in p.stdout:
                    self.q.put(("line", raw.decode("utf-8", "replace").rstrip("\r\n")))
                p.wait(timeout=600)
                self.q.put(("done", p.returncode))
            except Exception as e:  # noqa: BLE001
                self.q.put(("line", f"运行失败: {e}"))
                self.q.put(("done", -1))

        threading.Thread(target=work, daemon=True).start()

    def _drain(self):
        if not self.root.winfo_exists():
            return
        try:
            while True:
                kind, payload = self.q.get_nowait()
                if kind == "preview":
                    self._apply_preview(payload)
                    continue
                if kind == "line":
                    if payload.strip():
                        self.log(payload, self._tag_for(payload))
                else:
                    self._set_busy(False)
                    self._refresh_status()
                    if payload == 0 and getattr(self, "_pending_clears_dirty", False):
                        self._mark_clean(flash=True)
                    self.log("  ✔ 完成，新开一个终端标签页生效" if payload == 0
                             else f"  ✘ 退出码 {payload}", "ok" if payload == 0 else "err")
        except queue.Empty:
            pass
        self.root.after(120, self._drain)

    @staticmethod
    def _tag_for(line):
        s = line.strip()
        if s.startswith("[OK]") or "完成：" in s or s.startswith("完成"):
            return "ok"
        if s.startswith("[!!]"):
            return "warn"
        if s.startswith("[XX]") or "失败" in s or "错误" in s:
            return "err"
        if s.startswith("[1/3]") or s.startswith("[2/3]") or s.startswith("[3/3]"):
            return "title"
        return None

    def log(self, text, tag=None):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", (text or "") + "\n", tag or ())
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _clear_log(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")

    # ---------------- 动作
    def _apply(self):
        st = self._state()
        if st["style"] == "linux" and st["font_mode"] == "file" and st["font_file"]:
            if not os.path.exists(st["font_file"]):
                messagebox.showerror(APP_TITLE, f"字体文件不存在：\n{st['font_file']}")
                return
        if st["bg_enabled"]:
            if not st["bg_path"]:
                messagebox.showerror(APP_TITLE, "勾选了「启用背景图」但没选文件。\n\n" \
                                                "要么点「浏览」选一张，要么取消勾选。")
                return
            if not os.path.isfile(st["bg_path"]):
                messagebox.showerror(
                    APP_TITLE,
                    f"背景图文件不存在：\n{st['bg_path']}\n\n"
                    "如果它是被清理掉的旧图，请重新选一张；\n"
                    "如果本来就不想要背景图，先取消勾选「启用」。")
                return
        if st["cell_height"]:
            try:
                v = float(st["cell_height"])
                if not 0.8 <= v <= 2.0:
                    raise ValueError
            except ValueError:
                messagebox.showerror(APP_TITLE, "行高需要 0.8 - 2.0 之间的数字；留空表示不设置。")
                return
        self._run(build_apply_args(st), "保存设置", clears_dirty=True)

    def _to_win(self):
        self.var_style.set("win")
        self._on_style()
        self._run(["-win", "-transparent", "0", "/y"], "恢复 Windows 原生", clears_dirty=True)

    def _uninstall(self):
        if not messagebox.askyesno(APP_TITLE, "撤回本工具对外观 / 提示符 / cmd 挂钩的所有修改？\n（字体文件会保留）"):
            return
        self._run(["-uninstall", "/y"], "撤回外观修改")

    def _undo_cmd(self):
        self._run(["--undo-cmd", "/y"], "移除 cmd 提示符")

    def _diagnose(self):
        """在日志里打印环境诊断：设置文件在哪、当前窗口由谁渲染"""
        self._run(["-diagnose", "/y"], "环境诊断")

    def _install_fonts(self):
        self._run(["-install-fonts", "/y"], "安装内置字体")

    def _on_enc(self):
        self._run(["-encoding", "on" if self.var_enc.get() else "off", "/y"], "UTF-8 代码页")

    def _on_adapt(self):
        self._run(["-adaptive", "/y"] if self.var_adapt.get() else ["-adaptive", "off", "/y"],
                  "自适应前景色")

    def _uninstall_cmd(self):
        exe = find_installer()
        if not exe:
            messagebox.showinfo(APP_TITLE,
                                "没找到 install.exe。\n\n"
                                "请在命令行里执行：\n"
                                "  install.exe --uninstall\n\n"
                                "它会把 C:\\Program Files\\CLBT 里的文件和 PATH 条目一起清掉。")
            return
        if not messagebox.askyesno(APP_TITLE,
                                   f"彻底卸载命令行入口？\n{exe} --uninstall\n\n"
                                   "会删除工具本体并从 PATH 移除。"):
            return
        self.log("$ install.exe --uninstall", "cmd")
        try:
            p = subprocess.run([exe, "--uninstall", "--no-pause"], capture_output=True,
                               timeout=600, creationflags=0x08000000)
            for line in (p.stdout + p.stderr).decode("utf-8", "replace").splitlines():
                if line.strip():
                    self.log(line, self._tag_for(line))
            messagebox.showinfo(APP_TITLE, "卸载命令已执行，请重开终端。")
        except Exception as e:  # noqa: BLE001
            messagebox.showerror(APP_TITLE, f"执行失败：{e}")


# --------------------------------------------------------------------- 入口

def selftest():
    print(f"tool      = {find_tool()}")
    print(f"installer = {find_installer()}")
    cur = read_current_settings()
    print(f"settings  = {cur.get('path') if cur else '未找到'}")
    base = {"style": "linux", "transparent": 64, "acrylic": True,
            "bg_enabled": False, "bg_path": "",
            "bg_opacity": 0.55, "bg_align": "center", "bg_stretch": "uniformToFill",
            "font_mode": "face", "face": "0xProto Mono Italic", "weight": "normal", "font_file": "",
            "cell_height": "", "aa": "", "adjust": ""}
    print("默认状态 ->", build_apply_args(base))
    print("原生状态 ->", build_apply_args(dict(base, style="win", transparent=0)))
    print("全参数   ->", build_apply_args(dict(
        base, bg_enabled=True, bg_path=r"D:\pics\a.png", bg_opacity=0.3, bg_align="bottom",
        bg_stretch="none", font_mode="file", font_file=r"D:\fonts\x.ttf",
        cell_height="1.2", aa="grayscale", adjust="never")))
    tool = find_tool()
    if tool:
        p = subprocess.run([tool, "-install-fonts", "/y"], capture_output=True,
                           timeout=300, creationflags=0x08000000)
        print(f"install-fonts exit={p.returncode}")
        for line in (p.stdout + p.stderr).decode("utf-8", "replace").strip().splitlines():
            print("   ", line)
    return 0


def diag(path):
    """把 DPI / 环境诊断写到文件（--noconsole 打包后看不到 stdout，调试用）"""
    import ctypes
    lines = []
    try:
        r = ctypes.windll.shcore.SetProcessDpiAwareness(2)
        lines.append(f"SetProcessDpiAwareness(2) -> {r}")
    except Exception as e:
        lines.append(f"SetProcessDpiAwareness err: {e}")
    try:
        aw = ctypes.c_int()
        ctypes.windll.shcore.GetProcessDpiAwareness(None, ctypes.byref(aw))
        lines.append(f"process awareness = {aw.value} (0=unaware 1=system 2=permonitor)")
    except Exception as e:
        lines.append(f"GetProcessDpiAwareness err: {e}")
    try:
        from ctypes import wintypes
        mon = ctypes.windll.user32.MonitorFromPoint(wintypes.POINT(0, 0), 1)
        dx, dy = ctypes.c_uint(), ctypes.c_uint()
        r = ctypes.windll.shcore.GetDpiForMonitor(mon, 0, ctypes.byref(dx), ctypes.byref(dy))
        lines.append(f"GetDpiForMonitor -> {r} {dx.value}x{dy.value}")
    except Exception as e:
        lines.append(f"GetDpiForMonitor err: {e}")
    try:
        lines.append(f"GetDpiForSystem = {ctypes.windll.user32.GetDpiForSystem()}")
    except Exception as e:
        lines.append(f"GetDpiForSystem err: {e}")
    root = tk.Tk()
    try:
        lines.append(f"window_scale(root) = {window_scale(root)}")
    except Exception as e:
        lines.append(f"window_scale err: {e!r}")
    lines.append(f"winfo_fpixels(1i) = {root.winfo_fpixels('1i'):.2f}")
    lines.append(f"tk screen = {root.winfo_screenwidth()}x{root.winfo_screenheight()}")
    root.destroy()
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    return 0


def main():
    if "--diag" in sys.argv:
        set_dpi_aware()
        return diag(sys.argv[sys.argv.index("--diag") + 1])
    if "--selftest" in sys.argv:
        return selftest()

    set_dpi_aware()
    root = tk.Tk()
    root.app = App(root)   # 挂到 root 上，避免被 GC，也让 pyflakes 不再报未使用

    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
