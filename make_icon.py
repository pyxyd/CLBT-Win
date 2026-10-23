"""生成 CLBT 图标：深色圆角底 + 亮色 > 提示符，输出 PNG 与多尺寸 ICO"""
import os

from PIL import Image, ImageDraw

ROOT = r"D:\e2489fa5-12ed-4762-b054-dccb91f65c90"
DIST = os.path.join(ROOT, "dist")
S = 512          # 主画布尺寸
K = 4            # 超采样倍数（先画大再缩小，得到平滑边缘）
W = S * K

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# ---- 背景：圆角矩形 + 垂直渐变 ----
pad = 12 * K
radius = 108 * K
top_c = (44, 49, 60)
bot_c = (20, 22, 27)

bg = Image.new("RGBA", (W, W), (0, 0, 0, 0))
bd = ImageDraw.Draw(bg)
for y in range(W):
    t = y / (W - 1)
    r = int(top_c[0] + (bot_c[0] - top_c[0]) * t)
    g = int(top_c[1] + (bot_c[1] - top_c[1]) * t)
    b = int(top_c[2] + (bot_c[2] - top_c[2]) * t)
    bd.line([(0, y), (W, y)], fill=(r, g, b, 255))

mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle(
    [pad, pad, W - pad, W - pad], radius=radius, fill=255)
img.paste(bg, (0, 0), mask)

# ---- 边框：细亮线，增加立体感 ----
d.rounded_rectangle(
    [pad, pad, W - pad, W - pad], radius=radius,
    outline=(80, 92, 112, 255), width=3 * K)

# ---- 前景：> 提示符（两段粗线，圆头圆角）----
chev_w = 46 * K
cx, cy = 232 * K, 256 * K
arm = 100 * K
accent = (138, 226, 52, 255)      # 亮绿 #8AE234，与终端提示符同色

d.line([(cx - arm, cy - arm), (cx + arm // 2, cy)], fill=accent, width=chev_w, joint="curve")
d.line([(cx + arm // 2, cy), (cx - arm, cy + arm)], fill=accent, width=chev_w, joint="curve")
# 圆头补丁（line 的圆角端点）
for pt in ((cx - arm, cy - arm), (cx + arm // 2, cy), (cx - arm, cy + arm)):
    r = chev_w // 2
    d.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=accent)

# ---- 光标块：右下一个小方块，暗示终端 ----
cur_x, cur_w = 300 * K, 74 * K
d.rounded_rectangle(
    [cur_x, (cy + arm - 18 * K), cur_x + cur_w, (cy + arm + 26 * K)],
    radius=6 * K, fill=(211, 215, 207, 255))

# 缩小到目标尺寸
icon512 = img.resize((S, S), Image.LANCZOS)

png_path = os.path.join(DIST, "icon.png")
icon512.save(png_path, "PNG")
print(f"PNG: {png_path}")

# ---- 多尺寸 ICO ----
ico_path = os.path.join(DIST, "icon.ico")
sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
icon512.save(ico_path, format="ICO", sizes=sizes)
print(f"ICO: {ico_path}  ({os.path.getsize(ico_path)/1024:.1f} KB)")

# ---- 预览：把各尺寸并排拼一张，方便肉眼检查小尺寸可辨识度 ----
prev_w = 16 + 24 + 32 + 48 + 64 + 128 + 256 + 8 * 7
prev = Image.new("RGBA", (prev_w, 256), (250, 250, 250, 255))
x = 0
for s in (16, 24, 32, 48, 64, 128, 256):
    small = icon512.resize((s, s), Image.LANCZOS)
    prev.paste(small, (x, 256 - s - 8), small)
    x += s + 8
prev_path = os.path.join(DIST, "icon-preview.png")
prev.save(prev_path)
print(f"预览: {prev_path}")
