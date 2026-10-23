# 更新日志

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
