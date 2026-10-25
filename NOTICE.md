# 第三方资源归属

本项目分发/使用了下列第三方字体与图标集，请保留本文件。

## 字体：0xProto Nerd Font

- 上游：https://github.com/0xType/0xProto （版本 2.502）
- Nerd Fonts 补丁版：https://github.com/ryanoasis/nerd-fonts （release v3.5.1）
- 许可：**SIL Open Font License 1.1**
- 版权：Copyright (c) 2023, 0xType Project Authors
- 完整许可证见仓库根目录 `LICENSE`

### 本项目对字体所做的修改

将 `0xProtoNerdFontMono-Italic.ttf` 的 name 表改为独立家族
（家族名 `0xProto Mono Italic`、子族名 `Regular`，清除 italic/style 位），
使其在 Windows Terminal 中可作为独立字族被选用。字形本身未改动。

按 OFL 1.1 要求：衍生字体同样以 **OFL 1.1** 发布，且保留原始版权声明。
上游 LICENSE 未声明保留字体名（Reserved Font Name），故重命名不违反条款。

## 图标集（内嵌于 Nerd Fonts 补丁）

| 图标集 | 上游 | 版本 | 许可 |
|---|---|---|---|
| Codicons | https://github.com/microsoft/vscode-codicons | 0.0.45 | CC BY 4.0 |
| Devicons | https://github.com/devicons/devicon | 2.17.0 | MIT |
| extraglyphs | https://github.com/source-foundry/Hack | - | MIT |
| Font Awesome | https://github.com/FortAwesome/Font-Awesome | 6.5.1 | CC BY 4.0 |
| Font Awesome Extension | https://github.com/AndreLZGava/font-awesome-extension | 0.0.3 | MIT |
| Material Design Icons | https://github.com/Templarian/MaterialDesign | 0.13.0 | Apache 2.0 |
| Octicons | https://github.com/primer/octicons | 19.9.0 | MIT |
| Powerline Extra Symbols | https://github.com/ryanoasis/powerline-extra-symbols | 3.0.0 | MIT |
| Power Symbols | https://github.com/ryanoasis/powerline-extra-symbols | - | MIT |
| Weather Icons | https://github.com/erikflowers/weather-icons | 2.0.12 | SIL OFL 1.1 |

（图标集清单来自 Nerd Fonts 附带的 README，详见仓库根目录 `FONTS_README.md`）

## 其它

- Windows Terminal 的配色方案基于 Tango 调色板（GNOME Terminal 默认色板）
- 工具本身未包含任何 GPL 代码
