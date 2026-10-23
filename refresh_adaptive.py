"""把 adaptive-watch.ps1 的 base64 刷新进模板（脚本改动后调用）"""
import base64
import os
import sys

ROOT = r"D:\e2489fa5-12ed-4762-b054-dccb91f65c90"
SRC = os.path.join(ROOT, "terminal-setup.src.cmd")
W = os.path.join(ROOT, "adaptive-watch.ps1")

raw = open(W, "rb").read()
b64 = base64.b64encode(raw).decode("ascii")
blk = [b64[i:i + 76] for i in range(0, len(b64), 76)]

txt = open(SRC, encoding="utf-8-sig", newline=None).read().replace("\r\n", "\n")
lines = txt.split("\n")

start = None
for i, ln in enumerate(lines):
    if ln.startswith("$AdaptiveWatchB64"):
        start = i
        break
if start is None:
    sys.exit("找不到 $AdaptiveWatchB64 定义")

end = start + 1
while end < len(lines) and lines[end] != "'@":
    end += 1

out = lines[:start + 1] + blk + lines[end:]
with open(SRC, "w", encoding="utf-8", newline="\r\n") as f:
    f.write("\n".join(out))

print(f"base64 刷新完成: 旧 {end - start - 1} 行 -> 新 {len(blk)} 行（源 {len(raw)} 字节）")
