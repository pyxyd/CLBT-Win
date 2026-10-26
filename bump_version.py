#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CLBT 版本号管理（项目唯一版本源：version.json）
================================================

版本号格式  MAJOR.MIDDLE.MINOR，按 15 进制进位：

    1.0.13 → 1.0.14 → … → 1.0.15 → 1.1.1 → … → 1.1.15 → 1.2.1 …
    1.14.15 → 1.15.1 … → 1.15.15 → 2.0.1 → 2.0.2 …

    也就是：每 15 个小版本进 1 个中版本，每 15 个中版本进 1 个大版本；
    进位后低位从 1 重新开始（不留 0，0 只用在最初的 1.0.0）。

用法：
    python bump_version.py                 # 看当前版本和下一个版本（不写文件）
    python bump_version.py --next --write  # 进位并写进所有版本文件
    python bump_version.py --set 1.1.3 --write   # 指定版本并同步
    python bump_version.py --check         # 校验各文件是否与 version.json 一致（CI/发版前用）

规则实现见 Version.next()，有 5 个边界用例的回归测试：python bump_version.py --selftest
"""

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION_JSON = os.path.join(HERE, "version.json")
INFO_MAIN = os.path.join(HERE, "version_info.txt")
INFO_GUI = os.path.join(HERE, "version_info_gui.txt")
GUI_PY = os.path.join(HERE, "clbt_gui.py")

WRAP = 15  # 进位基数


class Version:
    __slots__ = ("major", "middle", "minor")

    def __init__(self, major=1, middle=0, minor=0):
        for n, v in (("major", major), ("middle", middle), ("minor", minor)):
            if not isinstance(v, int) or v < 0:
                raise ValueError(f"{n} 必须是非负整数，收到 {v!r}")
        if minor > WRAP or middle > WRAP:
            raise ValueError(f"中/小版本不能超过 {WRAP}（收到 {major}.{middle}.{minor}）")
        self.major, self.middle, self.minor = major, middle, minor

    # ---- 解析 / 输出
    @classmethod
    def parse(cls, text):
        m = re.fullmatch(r"\s*v?(\d+)\.(\d+)\.(\d+)\s*", str(text))
        if not m:
            raise ValueError(f"版本号格式应为 MAJOR.MIDDLE.MINOR，收到 {text!r}")
        return cls(int(m.group(1)), int(m.group(2)), int(m.group(3)))

    def __str__(self):
        return f"{self.major}.{self.middle}.{self.minor}"

    def __repr__(self):
        return f"Version({self})"

    def __eq__(self, other):
        return isinstance(other, Version) and str(self) == str(other)

    def __hash__(self):
        return hash(str(self))

    # ---- 进位规则
    def next(self):
        """每 15 个小版本进 1 个中版本，每 15 个中版本进 1 个大版本；
        进位后低位从 1 开始。"""
        if self.minor < WRAP:
            return Version(self.major, self.middle, self.minor + 1)
        # 小版本满 15 → 中版本 +1，小版本回到 1
        if self.middle < WRAP:
            return Version(self.major, self.middle + 1, 1)
        # 中版本也满 15 → 大版本 +1，中/小版本回到 0/1
        return Version(self.major + 1, 0, 1)


# --------------------------------------------------------------------- 文件读写

def _read(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return f.read()


def _write(path, text, newline="\n"):
    with open(path, "w", encoding="utf-8", newline=newline) as f:
        f.write(text)


INFO_TEMPLATE = """VSVersionInfo(
  ffi=FixedFileInfo(
    filevers=({major}, {middle}, {minor}, 0), prodvers=({major}, {middle}, {minor}, 0),
    mask=0x3f, flags=0x0, OS=0x40004, fileType=0x1, subtype=0x0, date=(0, 0)
  ),
  kids=[
    StringFileInfo([
      StringTable('080404B0', [
        StringStruct('CompanyName', 'CLBT'),
        StringStruct('FileDescription', '{desc}'),
        StringStruct('FileVersion', '{ver}'),
        StringStruct('InternalName', '{internal}'),
        StringStruct('LegalCopyright', 'Font: SIL OFL 1.1 (0xType Project Authors)'),
        StringStruct('OriginalFilename', '{exe}'),
        StringStruct('ProductName', 'CLBT'),
        StringStruct('ProductVersion', '{ver}')
      ])
    ]),
    VarFileInfo([VarStruct('Translation', [2052, 1200])])
  ]
)
"""


def load():
    if not os.path.isfile(VERSION_JSON):
        raise SystemExit(f"缺少版本源文件: {VERSION_JSON}")
    j = json.loads(_read(VERSION_JSON))
    for k in ("major", "middle", "minor"):
        if k not in j:
            raise ValueError(f"version.json 缺少字段 {k!r}")
    return Version(j["major"], j["middle"], j["minor"])


def sync_files(v, verbose=True):
    """把版本号写进 version.json / 两个 version_info / clbt_gui.py"""
    j = {"major": v.major, "middle": v.middle, "minor": v.minor}
    _write(VERSION_JSON, json.dumps(j, indent=2) + "\n")
    if verbose:
        print(f"  version.json           -> {v}")

    _write(INFO_MAIN, INFO_TEMPLATE.format(
        major=v.major, middle=v.middle, minor=v.minor, ver=f"{v}.0",
        desc="CLBT - Windows 命令行美化工具", internal="CLBT", exe="install.exe"))
    if verbose:
        print(f"  version_info.txt       -> {v}.0")

    _write(INFO_GUI, INFO_TEMPLATE.format(
        major=v.major, middle=v.middle, minor=v.minor, ver=f"{v}.0",
        desc="CLBT - 图形界面", internal="CLBT-GUI", exe="CLBT-GUI.exe"))
    if verbose:
        print(f"  version_info_gui.txt   -> {v}.0")

    src = _read(GUI_PY)
    new_src = re.sub(r'^VERSION = "[^"]*"$', f'VERSION = "{v}"', src, count=1, flags=re.M)
    if new_src == src and f'VERSION = "{v}"' not in src:
        raise SystemExit("clbt_gui.py 里找不到 VERSION 常量")
    _write(GUI_PY, new_src)
    if verbose:
        print(f"  clbt_gui.py VERSION    -> {v}")


def check(v):
    """各文件是否与 version.json 一致；返回问题列表（精确比对，不靠子串）"""
    problems = []
    want4 = (v.major, v.middle, v.minor, 0)
    want_s = f"{v}.0"
    pat_fixed = re.compile(
        r"filevers=\((\d+), (\d+), (\d+), (\d+)\), prodvers=\((\d+), (\d+), (\d+), (\d+)\)")

    for path in (INFO_MAIN, INFO_GUI):
        name = os.path.basename(path)
        try:
            txt = _read(path)
        except FileNotFoundError:
            problems.append(f"{name} 不存在")
            continue
        m = pat_fixed.search(txt)
        if not m:
            problems.append(f"{name} 里解析不到 filevers/prodvers")
        else:
            got = tuple(int(x) for x in m.groups())
            if got != want4 + want4:
                problems.append(f"{name} 的 filevers/prodvers 是 {got[:4]}/{got[4:]}，应为 {want4}")
        for key in ("FileVersion", "ProductVersion"):
            m2 = re.search(rf"StringStruct\('{key}', '([^']*)'\)", txt)
            if not m2:
                problems.append(f"{name} 缺少 {key} 字段")
            elif m2.group(1) != want_s:
                problems.append(f"{name} 的 {key} 是 {m2.group(1)}，应为 {want_s}")

    try:
        src = _read(GUI_PY)
    except FileNotFoundError:
        problems.append("clbt_gui.py 不存在")
        return problems
    m3 = re.search(r'^VERSION = "([^"]*)"$', src, re.M)
    if not m3:
        problems.append("clbt_gui.py 里找不到 VERSION 常量")
    elif m3.group(1) != str(v):
        problems.append(f"clbt_gui.py 的 VERSION 是 {m3.group(1)}，应为 {v}")
    return problems


# --------------------------------------------------------------------- CLI

def selftest():
    cases = [
        ("1.0.0", "1.0.1"),
        ("1.0.13", "1.0.14"),
        ("1.0.14", "1.0.15"),
        ("1.0.15", "1.1.1"),
        ("1.1.15", "1.2.1"),
        ("1.14.15", "1.15.1"),
        ("1.15.15", "2.0.1"),
        ("2.15.15", "3.0.1"),
    ]
    bad = 0
    for src, want in cases:
        got = str(Version.parse(src).next())
        ok = got == want
        bad += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] {src} -> {got}（期望 {want}）")
    # 非法输入
    for bad_s in ("1.0", "1.0.16", "a.b.c", "1..2"):
        try:
            Version.parse(bad_s)
            print(f"[FAIL] {bad_s!r} 应被拒绝")
            bad += 1
        except ValueError:
            print(f"[PASS] {bad_s!r} 被拒绝")
    print(f"\n{'全部通过' if not bad else f'{bad} 个失败'}")
    return 0 if not bad else 1


def main():
    try:
        return _main()
    except FileNotFoundError as e:
        print(f"[XX] 缺少文件: {e.filename or e}")
        return 2
    except KeyError as e:
        print(f"[XX] version.json 缺少字段: {e}")
        return 2
    except ValueError as e:
        print(f"[XX] {e}")
        return 2


def _main():
    ap = argparse.ArgumentParser(
        description="CLBT 版本号管理（15 进制进位：小版本满 15 进中，中版本满 15 进大）")
    ap.add_argument("--next", action="store_true", help="计算并（配合 --write）写入下一个版本")
    ap.add_argument("--set", metavar="X.Y.Z", help="直接指定版本")
    ap.add_argument("--write", action="store_true", help="真正写文件（默认只显示）")
    ap.add_argument("--check", action="store_true", help="校验各文件与 version.json 是否一致")
    ap.add_argument("--selftest", action="store_true", help="跑进位规则的回归用例")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    cur = load()
    if args.check:
        problems = check(cur)
        if problems:
            print(f"[XX] 版本不一致（version.json = {cur}）：")
            for p in problems:
                print("   -", p)
            return 1
        print(f"[OK] 所有版本文件一致：{cur}")
        return 0

    if args.set and args.next:
        print("[XX] --set 和 --next 不能同时用")
        return 2
    if args.set:
        target = Version.parse(args.set)
    elif args.next:
        target = cur.next()
    else:
        target = cur
        print(f"当前版本：{cur}")
        print(f"下一个版本：{cur.next()}（规则：小版本满 {WRAP} 进中，中版本满 {WRAP} 进大）")
        return 0

    print(f"当前版本：{cur}")
    print(f"目标版本：{target}")
    if not args.write:
        print("（这是预演，加 --write 才会写文件）")
        return 0
    sync_files(target)
    problems = check(target)
    if problems:
        print("[XX] 写入后自检失败：")
        for p in problems:
            print("   -", p)
        return 1
    print(f"[OK] 已同步为 {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
