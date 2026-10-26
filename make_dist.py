"""生成分发包 dist/CLBT.zip：README.txt + install.exe + CLBT-GUI.exe

包内三件：
  README.txt      说明
  install.exe     安装器（自带工具本体与字体，运行时写出 .cmd）
  CLBT-GUI.exe    图形界面（装完直接双击，也可以从 Program Files 里启动）
"""
import os
import zipfile

ROOT = r"D:\e2489fa5-12ed-4762-b054-dccb91f65c90"
DIST = os.path.join(ROOT, "dist")
os.makedirs(DIST, exist_ok=True)

README = """CLBT —— Windows 命令行美化工具
================================

压缩包里有三个文件：
  README.txt      本说明
  install.exe     安装器（工具本体 + 10 个字体都在它里面）
  CLBT-GUI.exe    图形界面，装完直接双击就能用

安装：
  1. 双击 install.exe（会弹一次 UAC，因为默认装到 C:\\Program Files\\CLBT）
  2. 它会写出三个文件到安装目录，并把该目录加入用户 PATH：
       terminal-setup.cmd   工具本体（33 MB，内嵌字体）
       CLBT.cmd             命令行入口
       CLBT-GUI.exe         图形界面（与压缩包里这份相同）
     想装到别处、不要管理员权限：install.exe --dir D:\\Tools\\CLBT
  3. 重新打开终端（重要，PATH 才会生效）
  4. 输入  CLBT -help  查看用法；或直接双击 CLBT-GUI.exe 开图形界面

图形界面：
  装之前双击 CLBT-GUI.exe 会提示找不到工具；
  装完之后双击它（压缩包里这份、或 C:\\Program Files\\CLBT\\那 份都行）即可。

常用命令：
  CLBT                              交互式菜单
  CLBT -gui                         打开图形界面（等价于双击 CLBT-GUI.exe）
  CLBT -linux                       仿 Linux：黑色亚克力 + bash 提示符
  CLBT -win                         Windows 原生风格
  CLBT -transparent 36              透明度 36%（即不透明度 64%）
  CLBT -opacity 64                  直接设置不透明度（100 = 完全不透明）
  CLBT -font "D:\\fonts\\x.ttf"       安装并使用指定字体（也可给目录）
  CLBT -face "0xProto Nerd Font"    直接用已安装的字族
  CLBT -install-fonts               只安装内置的 10 个字体，不改任何设置
  CLBT -adaptive                    开启自适应前景色（透明时按背景明暗切字体深浅）
  CLBT -adaptive off                关闭自适应前景色
  CLBT -encoding on|off             让 cmd 标签以 UTF-8 启动（消除 bat 中文乱码）
  CLBT -uninstall                   撤回对命令行的修改（外观/提示符/cmd 挂钩/自适应）
  install.exe --uninstall           卸载命令本身（清除 PATH + 删除 C:\\Program Files\\CLBT 里的文件）

两个口径别搞混：
  -transparent N    N 是「透明度」：0 = 完全不透明，100 = 全透
  -opacity N        N 是「不透明度」：与 Windows Terminal 的 opacity 同义

为什么工具本体由安装器写出，而不是直接放在压缩包里：
  这是个「批处理 + 内嵌脚本 + 内嵌字体」的单文件工具，对行尾极其敏感
  （必须是 CRLF）。聊天软件/编辑器/下载工具常把行尾转成 LF，一转就会
  让 cmd 把内嵌脚本当成命令执行，报一堆「xxx 不是内部或外部命令」。
  安装器把工具打包在 exe 内部，释放时总是正确的字节，彻底避免这个问题。

注意：
  · 默认安装目录是 C:\\Program Files\\CLBT，写入需要一次 UAC 授权
  · 用 --dir 指到当前用户可写的目录就完全不需要管理员权限
  · 只改用户 PATH（HKCU），不动系统 PATH，重复运行不会产生重复项
  · 装到新位置时会自动清理旧位置的 CLBT.cmd / terminal-setup.cmd（--keep-old 可保留）
  · 已存在的同名文件会先备份为 .bak
"""

readme_path = os.path.join(DIST, "README.txt")
with open(readme_path, "w", encoding="utf-8", newline="\r\n") as f:
    f.write(README)

ITEMS = [
    (os.path.join(DIST, "install.exe"), "CLBT/install.exe"),
    (os.path.join(DIST, "CLBT-GUI.exe"), "CLBT/CLBT-GUI.exe"),
    (readme_path, "CLBT/README.txt"),
]

for src, _ in ITEMS:
    if not os.path.isfile(src):
        raise SystemExit(f"缺少文件: {src}")

zip_path = os.path.join(DIST, "CLBT.zip")
if os.path.exists(zip_path):
    os.remove(zip_path)
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for src, arc in ITEMS:
        z.write(src, arc)

print("分发包内容：")
with zipfile.ZipFile(zip_path) as z:
    for i in z.infolist():
        print(f"  {i.filename:26} {i.file_size / 1048576:7.2f} MB")
    print(f"  解开后总计: {sum(i.file_size for i in z.infolist()) / 1048576:7.2f} MB")
print(f"  压缩后 zip: {os.path.getsize(zip_path) / 1048576:.2f} MB")
