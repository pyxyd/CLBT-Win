# 更新日志

## v1.0.10

### 新增环境诊断
- `CLBT -diagnose`（别名 `-doctor`）：一次说清「设置到底生效在哪」
  - 列出所有 settings.json 候选路径、是否存在、当前 `opacity` / `useAcrylic` / 背景图、最后修改时间
  - 打印当前窗口的进程链（`powershell → cmd → WindowsTerminal` 这种），判断当前窗口是不是真的 Windows Terminal
  - 打印已安装的 Terminal 版本、系统「透明效果」开关
  - 给出结论：如果宿主是 `Code.exe`（VS Code 集成终端）或传统 conhost，会直接提示「这里不读 Windows Terminal 的设置」
- 图形界面：底部新增「环境诊断」按钮，结果打到日志区
- 图形界面：透明度滑杆下面加了一句提醒——改的是 Windows Terminal 窗口，不是这个界面；
  点「应用外观」后要新开标签页才看得到

## v1.0.9

### 透明度调不动？加了亚克力开关
- 现象：滑杆拉来拉去，窗口看着几乎没变化。原因是「亚克力磨砂」一直开着，
  它给窗口加了一层磨砂材质，`opacity` 只影响磨砂层浓淡，看起来就像没生效。
- 新增 `CLBT -acrylic on|off`：
  - `on`（默认）= 磨砂玻璃，透明度变化比较含蓄
  - `off` = 关掉磨砂，`opacity` 直接生效，能看到桌面/后面的窗口
- 图形界面：风格卡片里加了「亚克力磨砂（关掉才是真透明）」勾选框，
  透明度那行会实时显示 `亚克力：磨砂玻璃` / `亚克力：关（真透明）`
- 交互菜单：高级微调里新增 `亚克力磨砂 1) 开 2) 关（真透明）`，摘要行也会打印
- 实测（纯红窗口垫底、20% 不透明度）：不透明度 100% 时终端区域接近黑，
  20% 时明显透出背景亮色，说明 `opacity` 本身是生效的

## v1.0.8

### 字体选项改短名
- 图形界面：字体卡片变成两个短下拉 —— **字形**（斜体 / 等宽 / 标准 / 比例）+
  **字重**（常规 / 粗体），不再显示 `0xProto Nerd Font Propo` 这种长名字
- 交互菜单：字体清单也显示短名（`1) 标准 2) 等宽 3) 比例 4) 斜体`），
  选中后括号里附上真实字族名；「高级微调」里新增 `字重 1) 常规 2) 粗体`
- 新增命令行参数 `CLBT -font-weight <normal|bold>`：常规 = 删掉 `font.weight`，
  粗体 = 写入 `"weight": "bold"`
- 选「常规」会显式写回 normal（而不是不发参数），保证从粗体切回来真的变细
- 字形、字重、自定义字体文件三者可以组合使用：`-face` + `-font-weight` / `-font`

## v1.0.7

### 压缩包结构
- CLBT.zip 里现在有三件东西（解压后是一个 CLBT 文件夹）：

  | 文件 | 大小 | 说明 |
  |---|---|---|
  | README.txt | 3 KB | 安装与用法说明 |
  | install.exe | 36 MB | 安装器（自带工具本体与 10 个字体） |
  | CLBT-GUI.exe | 11 MB | 图形界面，装完直接双击即可 |

- .cmd 仍然由 install.exe 在安装时写出（	erminal-setup.cmd + CLBT.cmd）：
  工具本体是「批处理 + 内嵌脚本 + 内嵌字体」，对行尾极其敏感，
  由安装器释放能保证永远是 CRLF，不会被聊天软件/编辑器改成 LF 而报错
- 压缩包从 35.79 MB 变成 46.42 MB（多出的就是 CLBT-GUI.exe 这一份）
- 解压目录里的 CLBT-GUI.exe 装完就能直接用（它会自己找
  C:\Program Files\CLBT\terminal-setup.cmd）；装之前双击会提示找不到工具

## v1.0.6

### 全面汉化
- 交互菜单：抗锯齿 / 背景图对齐 / 背景图拉伸 的选项都改成中文
  （灰度柔和、清晰锐利、像素风；居中、顶部、底部、左侧、右侧、左上、右上、左下、右下；
  铺满并裁剪、拉伸填满、完整显示、原始尺寸），原来只有 5 个的「背景图对齐」补全到 9 个
- 交互菜单：字体样式显示为「粗体 / 斜体 / 常规」，摘要行里的取值也用中文
- 交互菜单：中文也能直接输入 —— 填「右上」「灰度柔和」「铺满并裁剪」和填序号等价
- 图形界面：四个下拉框全部显示中文标签（居中、铺满并裁剪（推荐）、灰度柔和、总是修正…），
  内部仍然映射回命令行枚举值，日志里打印的命令与以前一模一样
- 图形界面：「不可辨色」改名「颜色修正」，下拉框加宽不再截断
- CLBT -help：每个取值后面都补了中文名，例如「背景图拉伸: 铺满并裁剪 uniformToFill / …」

## v1.0.5

### 安装器修复（重要）
- 换目录安装时不再丢 PATH 条目：以前「装到 D:\Tools\CLBT，而机器上已有
  C:\Program Files\CLBT」时，安装器会尝试清理旧安装 —— 删文件因权限失败，
  但 PATH 条目已经被移除，结果 `CLBT` 命令凭空消失。现在先探测旧目录是否可写，
  不可写就跳过清理并提示，**PATH 保持原样**。
- `install.exe --uninstall` 同理：只清理「能写」的目录，没权限的跳过并提示，
  不会顺手删掉另一份安装的 PATH 条目。

## v1.0.4

### 图形界面进入发布包
- `install.exe` 现在同时释放三件东西到 `C:\Program Files\CLBT`：
  `terminal-setup.cmd`（本体）、`CLBT.cmd`（入口）、**`CLBT-GUI.exe`**（11 MB，双击即用，不需要 Python）
- 新增 `CLBT -gui`：直接打开图形界面
- `install.exe --uninstall` 会把 GUI 一起清掉
- 分发包 `CLBT.zip` 从 25 MB 变成 36 MB，但仍只有一个附件、一个安装器

### 打包细节
- GUI 用 `--manifest gui.manifest` 声明 per-monitor DPI 感知；再按 `GetDpiForMonitor` 自行缩放，
  125% / 150% 缩放下窗口尺寸和字号都正确（原先会偏小）
- GUI 的界面尺寸按内容自适应，最小 1060×800，超出屏幕时按屏幕收窄

## v1.0.3

### 新增
- **图形界面 `clbt_gui.py`**（tkinter，零第三方依赖）：风格 / 透明度 / 背景图（浓淡·对齐·拉伸）/
  字体 / 行高 / 抗锯齿 / 不可辨色 / UTF-8 编码 / 自适应前景色，外加「恢复 Windows 原生」、
  「撤回外观修改」、「移除 cmd 提示符」、「卸载命令行入口」。日志区原样打印实际执行的命令和输出；
  打开时按当前 `settings.json` 预填，不会一上来就把设置覆盖成默认。
- `CLBT -face "<字族名>"`：直接指定已安装的字族（GUI 的字体下拉就用它，省得传字体文件路径）。
- `CLBT -install-fonts`：只安装内嵌的 10 个字体，不改任何外观设置。
- 图形界面按 DPI 感知渲染，125% / 150% 缩放下不会发虚或被裁掉。

## v1.0.2

### 修复（重要）
- 在**已经是 UTF-8（`chcp 65001`）的 cmd** 里运行任意 `CLBT` 命令（`-encoding on`、
  `-help`、`-linux` 都一样），开头会先冒出几行
  ```
  '--apply' is not recognized as an internal or external command,
  '5)' is not recognized as an internal or external command,
  ```
  原因：批处理区（`#::PS1::` 标记之前）里有中文注释、中文 `title` 和中文 `echo`。
  控制台处于代码页 65001 时，cmd 按「字符数」推算行偏移，多字节字符让偏移算错，
  `goto :label` 落到行中间，于是注释片段被当成命令执行了。
- 批处理区现在**全部改写成 ASCII 英文注释**；中文窗口标题改为在 PowerShell 正文里
  用 `$Host.UI.RawUI.WindowTitle` 设置；双击提示语改为 `Press any key to exit`。
- `build_package.py` 增加构建期检查：批处理区一旦出现非 ASCII 字符，直接报错退出，
  避免以后再踩回去。

### 说明
- 用管道/重定向（没有真实控制台）调用时看不到这个现象，只有在终端窗口里才会复现；
  起始代码页为 936 时也不复现，所以它只在「UTF-8 终端」里暴露。

## v1.0.1

### 安装位置
- 默认安装目录改为 `C:\Program Files\CLBT`（原来是 install.exe 自己所在的目录）
- 写入 Program Files 需要管理员权限，安装器会自动请求 UAC 提权，结果在管理员窗口里显示
- `--dir` 仍可装到任意目录；指到当前用户可写的位置就完全不需要管理员
- 装到新位置时自动清理旧位置的 `CLBT.cmd` / `terminal-setup.cmd` 并从 PATH 移除，避免旧路径抢先命中旧版本（`--keep-old` 可保留旧的）
- `--uninstall` 现在会连 `terminal-setup.cmd`（33 MB）和空目录一起清掉，并清理 PATH 里所有装过 CLBT 的目录

### 分发
- Release 只挂一个 `CLBT.zip`（安装器在包内），不再单独放 `install.exe`
- 安装器版本号 1.0.1.0

## v1.0.0

首个版本。

### 外观
- 仿 Linux 风格：黑色半透明亚克力 + Tango 配色 + 方块光标 + 隐藏滚动条
- Windows 原生风格：Campbell 配色、不透明、默认光标、默认提示符
- 透明度 / 不透明度两种口径（`-transparent` 与 `-opacity`）
- 背景图片：支持 png/jpg/jpeg/gif/bmp，可传目录；超大图自动缩放到 1920 宽
- 背景图浓淡自动跟随窗口透明度（水印策略），可用 `-bg-opacity` 手动指定
- 背景图对齐与拉伸可配置
- 字体：内置 10 个 0xProto Nerd Font 字体，可指定自定义字体文件/目录
- 行高（`cellHeight`）、抗锯齿模式、不可辨颜色修正

### 提示符与交互
- 仿 Linux 提示符 `user@host:~/path$`（家目录显示 `~`，管理员显示 `#`）
- 键位以 Windows 习惯为底（Ctrl+Z 撤销、Ctrl+A 全选、Tab 循环补全等全保留）
- 在 Windows 模式下空闲的键上补充 Linux 手感（Ctrl+E/U/K/P/N、Alt+B/F）
- cmd 提示符同样可仿 Linux（写入 `HKCU\...\Command Processor\AutoRun`，需在交互中确认）
- 自适应前景色守护：窗口透明时按背景明暗自动切换深/浅色文字，实时刷新

### 编码
- 安装时自动让 Terminal 的 cmd 标签以 UTF-8 启动（解决 bat 中文乱码）
- PowerShell profile 内设置 UTF-8 输出编码

### 分发
- 单文件 `install.exe`（自带字体、图标、版本信息，25 MB）
- 安装器只写当前用户 PATH，重复运行幂等
- `CLBT -uninstall` 撤回所有修改；`install.exe --uninstall` 卸载命令本身
- 分发包 zip 内附 README / 许可证

### 工程
- 模板与字体分离：`terminal-setup.src.cmd` + `build_package.py` 生成成品
- 成品为「批处理 + 内嵌 PowerShell 正文 + base64 字体」，必须 CRLF
- 守护脚本改为 base64 内嵌，避免嵌套 here-string 冲突
