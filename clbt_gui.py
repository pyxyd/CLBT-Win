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
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

APP_TITLE = "CLBT · Windows 命令行美化工具"
VERSION = "1.0.6"

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

FAMILIES = [
    "0xProto Mono Italic",
    "0xProto Nerd Font",
    "0xProto Nerd Font Mono",
    "0xProto Nerd Font Propo",
]
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

def find_tool():
    """terminal-setup.cmd：优先 Program Files，其次 PATH 里的 CLBT，最后脚本同级"""
    cands = [os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"),
                          "CLBT", "terminal-setup.cmd")]
    clbt = shutil.which("CLBT.cmd") or shutil.which("CLBT")
    if clbt:
        cands.append(os.path.join(os.path.dirname(clbt), "terminal-setup.cmd"))
    cands.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "terminal-setup.cmd"))
    for p in cands:
        if p and os.path.isfile(p):
            return p
    return None


def find_installer():
    here = os.path.dirname(os.path.abspath(__file__))
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
        if st["font_mode"] == "file" and st["font_file"]:
            args += ["-font", st["font_file"]]
        elif st["face"]:
            args += ["-face", st["face"]]

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
        return tk.Scale(parent, from_=lo, to=hi, resolution=res, orient="horizontal",
                        length=length, bg=CARD, fg=FG, troughcolor="#262626",
                        highlightthickness=0, bd=0, sliderrelief="flat",
                        activebackground=GREEN, font=MONO_S, showvalue=False,
                        command=cb or (lambda v: None))

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

        c, b = self._card(left, "字体（仿 Linux 风格生效）")
        c.pack(fill="x", pady=(0, 8))
        self.var_font_mode = tk.StringVar(value="face")
        self.var_face = tk.StringVar(value=FAMILIES[0])
        self.var_font_file = tk.StringVar(value="")
        line = tk.Frame(b, bg=CARD)
        line.pack(fill="x")
        self.cmb_face = ttk.Combobox(line, textvariable=self.var_face, values=FAMILIES,
                                     width=17, state="readonly", font=MONO_S)
        self.cmb_face.pack(side="left")
        self.cmb_face.bind("<<ComboboxSelected>>", lambda e: self.var_font_mode.set("face"))
        self._btn(line, "装内置字体", self._install_fonts, padx=8).pack(side="left", padx=(8, 0))
        line2 = tk.Frame(b, bg=CARD)
        line2.pack(fill="x", pady=(6, 0))
        self.entry_font = tk.Entry(line2, textvariable=self.var_font_file, bg=CARD2, fg=FG,
                                   font=MONO_S, insertbackground=FG, relief="flat", bd=4, width=1)
        self.entry_font.pack(side="left", fill="x", expand=True)
        self.entry_font.bind("<FocusIn>", lambda e: self.var_font_mode.set("file"))
        self._btn(line2, "浏览", self._pick_font, padx=8).pack(side="left", padx=(8, 0))
        tk.Label(b, text="字族走 -face，文件走 -font", bg=CARD, fg=DIM, font=MONO_S,
                 anchor="w").pack(fill="x", pady=(4, 0))

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

        g = tk.Frame(b, bg=CARD)
        g.pack(fill="x", pady=(6, 0))
        self.var_bg_op = tk.DoubleVar(value=0.22)
        tk.Label(g, text="浓淡", bg=CARD, fg=DIM, font=UI_S).grid(row=0, column=0, sticky="w")
        self.scale_bgop = self._slider(g, 0.05, 0.95, 0.22, res=0.01, length=120,
                                       cb=lambda v: self._on_bgop())
        self.scale_bgop.grid(row=0, column=1, sticky="w", padx=6)
        self.lbl_bgop = tk.Label(g, text="0.22", bg=CARD, fg=FG, font=MONO_S, width=4, anchor="w")
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

        c, b = self._card(right, "当前设置（读自 settings.json）")
        c.grid(row=1, column=0, sticky="ew", pady=(0, 8))
        self.lbl_cur = tk.Label(b, text="…", bg=CARD, fg=FG, font=MONO_S, justify="left",
                                anchor="w")
        self.lbl_cur.pack(fill="x")

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

        # ---- 底部按钮
        acts = tk.Frame(root, bg=BG)
        acts.grid(row=2, column=0, sticky="ew", padx=14, pady=(10, 12))
        b_apply = self._btn(acts, "应用外观", self._apply, bg="#1E3A2C", fg=GREEN, padx=16, pady=7)
        b_apply.pack(side="left")
        self.action_buttons.append(b_apply)
        for txt, fn in (("恢复 Windows 原生", self._to_win),
                        ("撤回外观修改", self._uninstall),
                        ("移除 cmd 提示符", self._undo_cmd),
                        ("卸载命令行入口", self._uninstall_cmd)):
            btn = self._btn(acts, txt, fn)
            btn.pack(side="left", padx=(8, 0))
            self.action_buttons.append(btn)
        self._btn(acts, "清空日志", self._clear_log, bg=CARD, fg=DIM).pack(side="right")

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
        if face in FAMILIES:
            self.var_face.set(face)
        bg = cur.get("bg")
        if bg and os.path.isfile(bg):
            self.var_bg.set(bg)
            self.var_bg_on.set(True)
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
        self._on_transp()
        self._on_bgop()
        self._on_bg_toggle()

    def _refresh_status(self):
        cur = read_current_settings()
        self.current = cur
        if not cur:
            self.lbl_cur.configure(text="找不到 Windows Terminal 的 settings.json")
            return
        op = cur.get("opacity")
        bg = cur.get("bg")
        rows = [
            ("不透明度", f"{op}%" if isinstance(op, int) else "（默认）"),
            ("亚克力", "开启" if cur.get("acrylic") else "关闭"),
            ("配色方案", cur.get("scheme") or "（默认）"),
            ("字体", (cur.get("face") or "系统默认") +
                     (f" {cur.get('size')}pt" if cur.get("size") else "")),
            ("背景图", os.path.basename(bg) if bg else "（无）"),
        ]
        if bg and cur.get("bgOpacity") is not None:
            rows.append(("背景浓淡", str(cur["bgOpacity"])))
        self.lbl_cur.configure(text="\n".join(f"{k}\t{v}" for k, v in rows))

    # ---------------- 回调
    def _on_transp(self):
        t = int(float(self.scale_transp.get()))
        self.var_transp.set(t)
        self.lbl_transp.configure(text=f"透明度 {t}%  →  不透明度 {100 - t}%")

    def _on_bgop(self):
        v = float(self.scale_bgop.get())
        self.var_bg_op.set(v)
        self.lbl_bgop.configure(text=f"{v:.2f}")

    def _on_bg_toggle(self):
        on = bool(self.var_bg_on.get())
        st = "normal" if on else "disabled"
        self.entry_bg.configure(state=st, bg=CARD2 if on else "#101010", fg=FG if on else DIM)
        self.scale_bgop.configure(state=st)

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
            "bg_enabled": bool(self.var_bg_on.get()),
            "bg_path": self.var_bg.get().strip(),
            "bg_opacity": float(self.var_bg_op.get()),
            "bg_align": value_of(ALIGN_CHOICES, self.var_align.get()),
            "bg_stretch": value_of(STRETCH_CHOICES, self.var_stretch.get()),
            "font_mode": self.var_font_mode.get(),
            "face": self.var_face.get(),
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

    def _run(self, args, title):
        if self.busy:
            return
        if not self.tool:
            messagebox.showerror(APP_TITLE, "找不到 terminal-setup.cmd，请先运行 install.exe。")
            return
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
        try:
            while True:
                kind, payload = self.q.get_nowait()
                if kind == "line":
                    if payload.strip():
                        self.log(payload, self._tag_for(payload))
                else:
                    self._set_busy(False)
                    self._refresh_status()
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
        if st["bg_enabled"] and st["bg_path"] and not os.path.isfile(st["bg_path"]):
            messagebox.showerror(APP_TITLE, f"背景图不存在：\n{st['bg_path']}")
            return
        if st["cell_height"]:
            try:
                v = float(st["cell_height"])
                if not 0.8 <= v <= 2.0:
                    raise ValueError
            except ValueError:
                messagebox.showerror(APP_TITLE, "行高需要 0.8 - 2.0 之间的数字；留空表示不设置。")
                return
        self._run(build_apply_args(st), "应用外观")

    def _to_win(self):
        self.var_style.set("win")
        self._on_style()
        self._run(["-win", "-transparent", "0", "/y"], "恢复 Windows 原生")

    def _uninstall(self):
        if not messagebox.askyesno(APP_TITLE, "撤回本工具对外观 / 提示符 / cmd 挂钩的所有修改？\n（字体文件会保留）"):
            return
        self._run(["-uninstall", "/y"], "撤回外观修改")

    def _undo_cmd(self):
        self._run(["--undo-cmd", "/y"], "移除 cmd 提示符")

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
    base = {"style": "linux", "transparent": 64, "bg_enabled": False, "bg_path": "",
            "bg_opacity": 0.22, "bg_align": "center", "bg_stretch": "uniformToFill",
            "font_mode": "face", "face": "0xProto Mono Italic", "font_file": "",
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
    app = App(root)

    root.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
