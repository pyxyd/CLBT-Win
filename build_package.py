"""
把字体文件以 base64 内嵌进 terminal-setup.cmd，生成真正「单文件可分享」的安装包。

用法：
    python build_package.py            # 打包全部字体（默认）
    python build_package.py --slim     # 只打包配置文件实际用到的那一个字体

产物：terminal-setup.cmd （覆盖）
源模板：terminal-setup.src.cmd （逻辑部分，由人工维护）

文件结构：
    [批处理头] + [#::PS1:: 之后的 PowerShell 正文] + [#::FONTS:: 之后的字体数据]

字体数据格式：
    #::FONTS::
    @FONT <文件名>
    <base64，每行 76 字符>
    @FONT <下一个文件名>
    ...
"""
import base64
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "terminal-setup.src.cmd")
OUT = os.path.join(HERE, "terminal-setup.cmd")
ITALIC_DIR = os.path.join(HERE, "italic-family")
VERSION_FILE = os.path.join(HERE, "version.json")

PS1_MARK = "#::PS1::"
FONT_MARK = "#::FONTS::"
VERSION_TOKEN = "@@VERSION@@"
LINE_WIDTH = 76

# 配置文件里实际引用的字体族（拆包时优先保证它在）
ESSENTIAL = ["0xProtoMonoItalic-Regular.ttf"]


def collect_fonts(slim: bool):
    """返回 [(文件名, 绝对路径)]"""
    fonts = []
    if slim:
        for name in ESSENTIAL:
            p = os.path.join(ITALIC_DIR, name)
            if os.path.exists(p):
                fonts.append((name, p))
        return fonts

    # 完整包：根目录的 9 个 + italic-family 里的 1 个
    for d in (HERE, ITALIC_DIR):
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.lower().endswith(".ttf"):
                fonts.append((fn, os.path.join(d, fn)))
    return fonts


def main():
    # 中文输出在 GBK 控制台下会乱码，统一改用 UTF-8
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    slim = "--slim" in sys.argv

    if not os.path.exists(SRC):
        sys.exit(f"找不到模板: {SRC}\n请先把当前 terminal-setup.cmd 复制为 terminal-setup.src.cmd")

    with open(SRC, "r", encoding="utf-8-sig") as f:
        template = f.read()

    # 注意：模板的代码里本来就引用这个标记串，所以不能做子串判断，
    # 只能是"存在一整行恰好等于标记"才说明混入了字体数据。
    if any(line.strip() == FONT_MARK for line in template.splitlines()):
        sys.exit("模板里已经含有字体数据段，请先清理模板再打包")

    # 模板必须以换行结尾，保证标记独占一行
    if not template.endswith("\n"):
        template += "\n"

    # 批处理区（#::PS1:: 标记行之前）必须纯 ASCII：
    # 在 chcp 65001 的控制台里，cmd 解析含多字节字符的批处理会算错行偏移，
    # goto 落到行中间，把注释片段当命令执行
    #（现象：'5)' is not recognized as an internal or external command）。
    lines = template.splitlines()
    marks = [i for i, ln in enumerate(lines) if ln.strip() == PS1_MARK]
    if not marks:
        sys.exit(f"模板里找不到 {PS1_MARK} 标记行")
    head = lines[:marks[-1]]
    bad = [(i + 1, ln) for i, ln in enumerate(head) if any(ord(c) > 127 for c in ln)]
    if bad:
        print("错误: 批处理区（标记行之前）出现了非 ASCII 字符。")
        print("      chcp 65001 下 cmd 会算错行偏移，把注释片段当命令执行。")
        print("      请把这些文字挪进 PowerShell 正文，或用英文注释：")
        for n, ln in bad[:10]:
            print(f"      行 {n}: {ln[:90]}")
        sys.exit(1)

    fonts = collect_fonts(slim)
    if not fonts:
        sys.exit("没有找到任何 .ttf 字体文件")

    # 版本号注入：模板里写 $CLBT_VERSION = '@@VERSION@@'，这里换成 version.json 的值
    try:
        with open(VERSION_FILE, "r", encoding="utf-8") as f:
            vj = json.load(f)
        version = "%d.%d.%d" % (vj["major"], vj["middle"], vj["minor"])
    except Exception as e:  # noqa: BLE001
        sys.exit(f"读不到版本号（{VERSION_FILE}）: {e}")
    if VERSION_TOKEN not in template:
        sys.exit(f"模板里找不到版本占位符 {VERSION_TOKEN}")
    template = template.replace(VERSION_TOKEN, version)

    parts = [template, FONT_MARK, "\n"]
    total_raw = 0
    total_b64 = 0
    report = []

    for name, path in fonts:
        with open(path, "rb") as f:
            raw = f.read()
        b64 = base64.b64encode(raw).decode("ascii")
        total_raw += len(raw)
        total_b64 += len(b64)
        digest = hashlib.sha256(raw).hexdigest()

        parts.append(f"@FONT {name}\n")
        for i in range(0, len(b64), LINE_WIDTH):
            parts.append(b64[i:i + LINE_WIDTH] + "\n")

        report.append((name, len(raw), digest))

    content = "".join(parts)

    # 统一 CRLF（批处理必须是 CRLF，否则 cmd 会把正文当命令执行）
    content = content.replace("\r\n", "\n").replace("\n", "\r\n")

    # UTF-8 无 BOM
    with open(OUT, "wb") as f:
        f.write(content.encode("utf-8"))

    size = os.path.getsize(OUT)
    print(f"已生成: {OUT}")
    print(f"  版本号: {version}")
    print(f"  字体数: {len(fonts)}   原始合计: {total_raw/1048576:.2f} MB   base64: {total_b64/1048576:.2f} MB")
    print(f"  产物大小: {size/1048576:.2f} MB")
    print("  已内嵌字体:")
    for name, n, digest in report:
        print(f"    {name:<38} {n/1048576:5.2f} MB  sha256={digest[:16]}…")


if __name__ == "__main__":
    main()
