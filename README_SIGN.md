# 代码签名说明

## 三条路线

| 路线 | 成本 | 能否消除 SmartScreen | 适合谁 |
|---|---|---|---|
| 自签名证书 | 免费 | **不能**（显示"未知发布者"，对方需手动信任根证书） | 仅内测 |
| Certum Open Source Code Signing | 约 €30-60/年 | 需信誉积累 | **个人/开源，最现实** |
| SignPath Foundation | 免费（需开源审核） | 需信誉积累 | 开源项目 |
| Azure Trusted Signing | 约 $10/月 | 需信誉积累 | 有 Azure 账号 + 主体验证 |
| OV 商业证书 | $200-400/年 | 需信誉积累（累计下载量） | 有企业资质 |
| EV 商业证书 | $300-600/年 | **立刻消除** | 有企业资质 + 预算 |

## 关键真相

1. **签名 ≠ 免杀**。PyInstaller 产物被杀软启发式判定，签名后仍可能被报毒，需要向各家提交误报。
2. **OV 不会立刻消 SmartScreen**，要累积下载信誉；**EV 才有立即信誉**。
3. **每次重新打包，文件哈希都变**，OV 的信誉会重新开始积累（EV 不受影响）。
4. 自签名证书在**别人机器上无效**（证书链断），只能自己测试。演示时 `signtool verify` 会报
   「certificate chain processed, but terminated in a root」——这是预期结果。

## 用法

```bat
rem 自动挑已安装的证书
sign.cmd

rem 指定证书指纹
sign.cmd dist\install.exe <证书指纹>

rem 用 PFX 文件
sign.cmd dist\install.exe pfx cert.pfx 密码
```

脚本里已包含**时间戳**（`http://timestamp.digicert.com`）——不带时间戳的话，
证书到期后签名会一起失效。

## 签名前先补版本信息

当前 exe 的 FileDescription / ProductName 是空的，签名后看起来仍不像正规软件。
构建时加：

```bat
python -m PyInstaller --onefile --console --name install ^
  --distpath dist --workpath build --specpath build --noconfirm ^
  --icon dist\icon.ico ^
  --version-file version_info.txt ^
  --add-data "terminal-setup.cmd;." install.py
```

然后再 `sign.cmd`。

## 国内个人申请注意

- OV/EV 商业证书基本要求**企业营业执照**，个人较难直接申请。
- 想低成本合规：**Certum 的 Open Source Code Signing**（支持个人，云签名 SimplySign，无需硬件 token）。
- 微软官方云签名 **Azure Trusted Signing**（约 $10/月）不需要硬件 token，但要过主体验证。
