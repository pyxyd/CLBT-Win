@echo off
rem  ====================================================================
rem   CLBT - Windows command line beautifier (single file with fonts)
rem
rem   Usage: double-click it, or  terminal-setup.cmd /y   (/y = no pause)
rem          terminal-setup.cmd --apply "<face>" /y      (silent apply)
rem          terminal-setup.cmd --undo-cmd /y            (remove cmd prompt)
rem
rem   ------------------------------------------------------------------
rem   !! MAINTENANCE NOTES !!
rem   This file is one batch file carrying an embedded PowerShell payload
rem   plus embedded font data:
rem     1) Line endings MUST be CRLF. With LF, goto/exit break and cmd
rem        executes the payload as batch commands (weird syntax errors).
rem     2) Encoding is UTF-8 (no BOM needed).
rem     3) Each payload marker line (PS1 / FONTS) must appear exactly once.
rem     4) The payload must never contain the marker string literally: the
rem        launcher locates it by string search. Build it by concatenation.
rem     5) Font data is appended by build_package.py; do not edit by hand.
rem   ------------------------------------------------------------------
rem   !! KEEP THE BATCH REGION PURE ASCII !!
rem   Non-ASCII text here (Chinese comments, a localized title, ...) breaks
rem   cmd's own line bookkeeping once the console runs at code page 65001:
rem   "goto :label" then lands mid-line and stray fragments get executed as
rem   commands, e.g.  '5)' is not recognized as an internal or external
rem   command. Keep every line up to the PS1 marker ASCII-only; put all
rem   non-ASCII text inside the PowerShell payload, which is read as UTF-8.
rem   ====================================================================
setlocal
rem  remember the console code page (setlocal/endlocal do NOT roll it back)
set "WT_OLDCP="
for /f "tokens=2 delims=:" %%c in ('chcp') do set "WT_OLDCP=%%c"
set "WT_OLDCP=%WT_OLDCP: =%"
chcp 65001 >nul 2>&1
set "WT_SELF=%~f0"
set "WT_SELF_DIR=%~dp0"
set "WT_MODE="
set "WT_FACE="
set "WT_FONTWEIGHT="
set "WT_ACRYLIC="
set "WT_NOPAUSE="
set "WT_STYLE="
set "WT_TRANSPARENT="
set "WT_FONTFILE="
set "WT_OPACITY="
set "WT_ADAPTIVE="
set "WT_BACKGROUND="
set "WT_ADJUST="
set "WT_ENCODING="
set "WT_CELLHEIGHT="
set "WT_AA="
set "WT_BGALIGN="
set "WT_BGOPACITY="
set "WT_BGSTRETCH="
set "WT_RC=0"

:parse
if "%~1"=="" goto :launch
if /i "%~1"=="-help" goto :arg_help
if /i "%~1"=="--help" goto :arg_help
if /i "%~1"=="-h" goto :arg_help
if /i "%~1"=="/?" goto :arg_help
if /i "%~1"=="-linux" goto :arg_linux
if /i "%~1"=="-win" goto :arg_win
if /i "%~1"=="-transparent" goto :arg_trans
if /i "%~1"=="-font" goto :arg_font
if /i "%~1"=="--font" goto :arg_font
if /i "%~1"=="-face" goto :arg_face
if /i "%~1"=="-acrylic" goto :arg_acrylic
if /i "%~1"=="--acrylic" goto :arg_acrylic
if /i "%~1"=="-font-weight" goto :arg_fontweight
if /i "%~1"=="--font-weight" goto :arg_fontweight
if /i "%~1"=="--face" goto :arg_face
if /i "%~1"=="-install-fonts" goto :arg_ifonts
if /i "%~1"=="-gui" goto :arg_gui
if /i "%~1"=="-diagnose" goto :arg_diag
if /i "%~1"=="-doctor" goto :arg_diag
if /i "%~1"=="--install-fonts" goto :arg_ifonts
if /i "%~1"=="-opacity" goto :arg_opacity
if /i "%~1"=="--opacity" goto :arg_opacity
if /i "%~1"=="-encoding" goto :arg_encoding
if /i "%~1"=="--encoding" goto :arg_encoding
if /i "%~1"=="-adjust-colors" goto :arg_adjust
if /i "%~1"=="-cell-height" goto :arg_cellh
if /i "%~1"=="-antialiasing" goto :arg_aa
if /i "%~1"=="-bg-opacity" goto :arg_bgopacity
if /i "%~1"=="-bg-align" goto :arg_bgalign
if /i "%~1"=="-bg-stretch" goto :arg_bgstretch
if /i "%~1"=="-background" goto :arg_background
if /i "%~1"=="--background" goto :arg_background
if /i "%~1"=="-adaptive" goto :arg_adaptive
if /i "%~1"=="--adaptive" goto :arg_adaptive
if /i "%~1"=="-uninstall" goto :arg_uninstall
if /i "%~1"=="--uninstall" goto :arg_uninstall
if /i "%~1"=="--transparent" goto :arg_trans
if /i "%~1"=="--style" goto :arg_style
if /i "%~1"=="--apply" goto :arg_apply
if /i "%~1"=="--undo-cmd" goto :arg_undo
if /i "%~1"=="/y" goto :arg_nopause
rem unknown argument: fail fast so a typo never silently rewrites settings
set "WT_MODE=badarg"
set "WT_BADARG=%~1"
goto :launch

:arg_help
set "WT_MODE=help"
goto :launch

:arg_linux
set "WT_MODE=cli"
set "WT_STYLE=linux"
shift
goto :parse

:arg_win
set "WT_MODE=cli"
set "WT_STYLE=win"
shift
goto :parse

:arg_style
set "WT_MODE=cli"
set "WT_STYLE=%~2"
shift
shift
goto :parse

:arg_font
set "WT_MODE=cli"
set "WT_FONTFILE=%~2"
shift
shift
goto :parse

:arg_face
set "WT_MODE=cli"
set "WT_FACE=%~2"
shift
shift
goto :parse

:arg_acrylic
set "WT_MODE=cli"
set "WT_ACRYLIC=%~2"
shift
shift
goto :parse

:arg_fontweight
set "WT_MODE=cli"
set "WT_FONTWEIGHT=%~2"
shift
shift
goto :parse

:arg_ifonts
set "WT_MODE=installfonts"
goto :launch

:arg_diag
set "WT_MODE=diag"
goto :launch

:arg_gui
if exist "%~dp0CLBT-GUI.exe" goto :arg_gui_run
echo CLBT-GUI.exe not found next to this script -- run install.exe first.
set "WT_RC=1"
goto :done
:arg_gui_run
start "" "%~dp0CLBT-GUI.exe" >nul 2>&1
set "WT_RC=0"
goto :done

:arg_trans
set "WT_MODE=cli"
set "WT_TRANSPARENT=%~2"
shift
shift
goto :parse

:arg_apply
set "WT_MODE=apply"
set "WT_FACE=%~2"
goto :launch

:arg_nopause
set "WT_NOPAUSE=1"
shift
goto :parse

:arg_opacity
set "WT_MODE=cli"
set "WT_OPACITY=%~2"
shift
shift
goto :parse

:arg_encoding
set "WT_MODE=encoding"
set "WT_ENCODING=on"
if /i "%~2"=="off" set "WT_ENCODING=off"
goto :launch

:arg_adjust
set "WT_MODE=cli"
set "WT_ADJUST=%~2"
shift
shift
goto :parse

:arg_cellh
set "WT_MODE=cli"
set "WT_CELLHEIGHT=%~2"
shift
shift
goto :parse

:arg_aa
set "WT_MODE=cli"
set "WT_AA=%~2"
shift
shift
goto :parse

:arg_bgopacity
set "WT_MODE=cli"
set "WT_BGOPACITY=%~2"
shift
shift
goto :parse

:arg_bgalign
set "WT_MODE=cli"
set "WT_BGALIGN=%~2"
shift
shift
goto :parse

:arg_bgstretch
set "WT_MODE=cli"
set "WT_BGSTRETCH=%~2"
shift
shift
goto :parse

:arg_background
set "WT_MODE=cli"
set "WT_BACKGROUND=%~2"
shift
shift
goto :parse

:arg_adaptive
set "WT_MODE=adaptive"
set "WT_ADAPTIVE=on"
if /i "%~2"=="off" set "WT_ADAPTIVE=off"
goto :launch

:arg_uninstall
set "WT_MODE=uninstall"
shift
goto :parse

:arg_undo
set "WT_MODE=undo"
goto :launch

:launch
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw=[System.IO.File]::ReadAllText($env:WT_SELF,[System.Text.Encoding]::UTF8); $i=$raw.LastIndexOf('#::PS1::'); if($i -lt 0){ Write-Host 'ERROR: payload marker not found' -ForegroundColor Red; exit 1 }; $f=$raw.IndexOf('#::FONTS::',$i); if($f -lt 0){ $code=$raw.Substring($i+8) } else { $code=$raw.Substring($i+8,$f-($i+8)) }; $tmp=Join-Path $env:TEMP ('wtsetup_'+[guid]::NewGuid().ToString('N')+'.ps1'); [System.IO.File]::WriteAllText($tmp,$code,(New-Object System.Text.UTF8Encoding($true))); try { & $tmp } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }; if ($null -ne $LASTEXITCODE) { exit $LASTEXITCODE } else { exit 0 }"
set "WT_RC=%ERRORLEVEL%"

echo.
if defined WT_MODE goto :done
if defined WT_NOPAUSE goto :done
echo  Press any key to exit . . .
pause >nul
:done
call :restore_cp
endlocal & exit /b %WT_RC%

:restore_cp
rem  restore the original code page before leaving
if defined WT_OLDCP if not "%WT_OLDCP%"=="65001" chcp %WT_OLDCP% >nul 2>&1
exit /b 0

#::PS1::
# =====================================================================
#  Windows 命令行美化工具
#
#  交互式：选择字体 → 应用黑色亚克力外观 + bash 风格提示符
#  静默式：由本脚本以 --apply "<字体名>" 自调用，实际执行美化动作
#
#  不需要管理员权限；可重复运行；改动前自动备份。
#  可选环境变量：
#    WT_SETTINGS_PATH / WT_PROFILE_DIR / WT_FONT_DIR / WT_FONT_OUT
# =====================================================================

$ErrorActionPreference = 'Stop'

# 标题：先记下原值再改，退出时还原（批处理区不设标题，避免退出后残留）
$__oldTitle = $null
try { $__oldTitle = $Host.UI.RawUI.WindowTitle } catch { }
try { $Host.UI.RawUI.WindowTitle = 'Windows 命令行美化工具' } catch { }

$MARK_FONTS = ('#::' + 'FONTS' + '::')   # 拼接构造：正文里不能出现字面量

function Read-Answer {
    # 交互菜单专用：stdin 被重定向/关闭时直接取消，绝不能当成「空回车 = 默认值」
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) {
        Write-Host ''
        Write-Host '  输入已结束（stdin 被重定向或关闭），交互菜单需要键盘输入，已取消。' -ForegroundColor Yellow
        Write-Host '  非交互场景请直接用参数，例如： CLBT -linux -transparent 36' -ForegroundColor Gray
        exit 1
    }
    return $line
}

function Info($m) { Write-Host $m -ForegroundColor Cyan }
function Good($m) { Write-Host "  [OK]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!]   $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "  [XX]   $m" -ForegroundColor Red }

# =====================================================================
# 工具函数
# =====================================================================
function Strip-JsonComments([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    $inStr = $false; $esc = $false; $i = 0
    while ($i -lt $s.Length) {
        $ch = $s[$i]
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($esc) { $esc = $false }
            elseif ($ch -eq '\') { $esc = $true }
            elseif ($ch -eq '"') { $inStr = $false }
            $i++
        }
        elseif ($ch -eq '"') { $inStr = $true; [void]$sb.Append($ch); $i++ }
        elseif ($ch -eq '/' -and ($i + 1) -lt $s.Length -and $s[$i + 1] -eq '/') {
            while ($i -lt $s.Length -and $s[$i] -ne "`n") { $i++ }
        }
        elseif ($ch -eq '/' -and ($i + 1) -lt $s.Length -and $s[$i + 1] -eq '*') {
            $i += 2
            while (($i + 1) -lt $s.Length -and -not ($s[$i] -eq '*' -and $s[$i + 1] -eq '/')) { $i++ }
            $i += 2
        }
        else { [void]$sb.Append($ch); $i++ }
    }
    return $sb.ToString()
}

function Set-Prop($obj, [string]$name, $value) {
    if ($null -eq $obj) { return }
    if ($obj.PSObject.Properties.Name -contains $name) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }
}

function Get-FontStyleOf([string]$baseName) {
    if ($baseName -match '-BoldItalic$') { return 'Bold Italic' }
    if ($baseName -match '-Bold$')       { return 'Bold' }
    if ($baseName -match '-Italic$')     { return 'Italic' }
    if ($baseName -match '-Oblique$')    { return 'Italic' }
    return 'Regular'
}

function Test-FontFamilyInstalled([string]$Name) {
    # 判断字族名是否真的存在：GDI+ 装上就能 new 出来，不存在会抛
    if (-not $Name) { return $false }
    try {
        if (-not ('System.Drawing.FontFamily' -as [type])) { Add-Type -AssemblyName System.Drawing -ErrorAction Stop }
        $f = New-Object System.Drawing.FontFamily($Name)
        return [bool]$f
    }
    catch { return $false }
}

function Get-FamilyOf([string]$path, [string]$fallback) {
    try {
        if (-not ('System.Drawing.Text.PrivateFontCollection' -as [type])) { Add-Type -AssemblyName System.Drawing }
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile($path)
        if ($pfc.Families.Count -gt 0) { $n = $pfc.Families[0].Name } else { $n = $fallback }
        $pfc.Dispose()
        return $n
    } catch { return $fallback }
}

# 把内嵌字体解码到指定目录，返回文件列表
function Expand-EmbeddedFonts([string]$stageDir) {
    $files = New-Object System.Collections.ArrayList
    if (-not $stageDir) { return $files }
    if (-not (Test-Path -LiteralPath $stageDir)) { New-Item -ItemType Directory -Path $stageDir -Force | Out-Null }

    $sr = New-Object System.IO.StreamReader($env:WT_SELF, [System.Text.Encoding]::UTF8)
    $inFonts = $false
    $name = $null
    $b64 = New-Object System.Text.StringBuilder
    while ($null -ne ($ln = $sr.ReadLine())) {
        if (-not $inFonts) {
            if ($ln.Trim() -eq $MARK_FONTS) { $inFonts = $true }
            continue
        }
        $t = $ln.Trim()
        if ($t -like '@FONT *') {
            if ($name -and $b64.Length -gt 0) {
                try {
                    $out = Join-Path $stageDir $name
                    [System.IO.File]::WriteAllBytes($out, [Convert]::FromBase64String($b64.ToString()))
                    [void]$files.Add((Get-Item -LiteralPath $out))
                } catch { Bad "内嵌字体 $name 解码失败: $($_.Exception.Message)" }
            }
            $name = $t.Substring(6).Trim()
            $b64.Length = 0
        }
        elseif ($t) { [void]$b64.Append($t) }
    }
    if ($name -and $b64.Length -gt 0) {
        try {
            $out = Join-Path $stageDir $name
            [System.IO.File]::WriteAllBytes($out, [Convert]::FromBase64String($b64.ToString()))
            [void]$files.Add((Get-Item -LiteralPath $out))
        } catch { Bad "内嵌字体 $name 解码失败: $($_.Exception.Message)" }
    }
    $sr.Close()
    return $files
}

# =====================================================================
# 安装一个外部字体文件（供 CLBT -font 使用）
#   返回字体族名；按当前用户安装，已存在则跳过
# =====================================================================
function Install-FontFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "字体路径不存在: $Path" }
    if (-not ('System.Drawing.Text.PrivateFontCollection' -as [type])) { Add-Type -AssemblyName System.Drawing }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        $files = @(Get-ChildItem -LiteralPath $item.FullName -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Extension -in @('.ttf', '.otf', '.ttc') })
    }
    else {
        if ($item.Extension -notin @('.ttf', '.otf', '.ttc')) {
            throw "不是字体文件（需要 .ttf/.otf/.ttc）: $($item.Name)"
        }
        $files = @($item)
    }
    if ($files.Count -eq 0) { throw "该路径下没有字体文件: $Path" }

    $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (-not (Test-Path -LiteralPath $userFontDir)) { New-Item -ItemType Directory -Path $userFontDir -Force | Out-Null }
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }

    $hkNames = @(); $cuNames = @()
    try { $hkNames = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties.Name } catch { }
    try { $cuNames = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).PSObject.Properties.Name } catch { }

    $firstFamily = $null
    $installed = 0; $skipped = 0
    foreach ($f in $files) {
        $fam = Get-FamilyOf $f.FullName $f.BaseName
        if (-not $firstFamily) { $firstFamily = $fam }
        $style = Get-FontStyleOf $f.BaseName
        $regName = if ($style -eq 'Regular') { "$fam (TrueType)" } else { "$fam $style (TrueType)" }

        if (($hkNames -contains $regName) -or ($cuNames -contains $regName)) { $skipped++; continue }

        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $userFontDir $f.Name) -Force
        New-ItemProperty -Path $reg -Name $regName -Value (Join-Path $userFontDir $f.Name) -PropertyType String -Force | Out-Null
        $installed++
    }
    Write-Host ("  字体安装：新增 " + $installed + " 个，已存在 " + $skipped + " 个") -ForegroundColor Gray
    return $firstFamily
}

# =====================================================================
# 核心：应用美化（由 --apply 子进程调用）
# =====================================================================
function Save-DefaultsSnapshot($d) {
    # 第一次改动 defaults 之前，把用户自己配的 font / padding / scrollbarState 存到旁边，
    # -uninstall 时还原：避免「跑一次 -win 就把你的字体设置删了」
    try {
        $dir = Get-AdaptiveDir
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $f = Join-Path $dir 'defaults-snapshot.json'
        if (Test-Path -LiteralPath $f) { return }
        $snap = [pscustomobject]@{}
        foreach ($k in @('font', 'padding', 'scrollbarState')) {
            if ($d.PSObject.Properties.Name -contains $k) {
                Add-Member -InputObject $snap -NotePropertyName $k -NotePropertyValue $d.$k
            }
        }
        [System.IO.File]::WriteAllText($f, ($snap | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
    }
    catch { }
}

function Invoke-Beautify([string]$Face, [string]$Style = 'linux', [int]$Opacity = -1, [string]$Background = '',
    [string]$AdjustColors = '', [string]$CellHeight = '', [string]$Antialiasing = '',
    [string]$BgAlign = '', [string]$BgStretch = '', [string]$BgOpacity = '',
    [string]$FontWeight = '', [string]$Acrylic = '') {
    # Opacity < 0 表示按风格取默认值（linux 36% / win 100%）
    if ($Opacity -lt 0) { $Opacity = if ($Style -eq 'win') { 100 } else { 36 } }

    # -----------------------------------------------------------------
    # 1) 终端外观
    # -----------------------------------------------------------------
    Info '[1/3] 终端外观'

    $settingsPath = $env:WT_SETTINGS_PATH
    if (-not $settingsPath) {
        $cands = @(
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal Preview\settings.json')
        )
        $settingsPath = $cands | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }

    if ($settingsPath -and (Test-Path -LiteralPath $settingsPath)) {
        $backup = "$settingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $settingsPath -Destination $backup -Force
        Good "已备份: $(Split-Path -Leaf $backup)"
        # settings.json 通常带整段注释；重写会丢注释与排版，先说清楚（原件在 .bak 里）
        try {
            $rawForHint = [System.IO.File]::ReadAllText($settingsPath, [System.Text.UTF8Encoding]::new($false))
            if ($rawForHint -match '(?m)^\s*(//|/\*)') {
                Warn 'settings.json 含注释：本次会重写该文件，注释与排版不保留（原文件见上面的 .bak）'
            }
        }
        catch { }
        # 只留最近 10 份 .bak-*，避免 LocalState 里堆出几百个
        try {
            $bkDir = Split-Path -Parent $settingsPath
            $bkLeaf = Split-Path -Leaf $settingsPath
            Get-ChildItem -LiteralPath $bkDir -Filter ($bkLeaf + '.bak-*') -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        }
        catch { }

        $raw = [System.IO.File]::ReadAllText($settingsPath, [System.Text.UTF8Encoding]::new($false))
        $j = (Strip-JsonComments $raw) | ConvertFrom-Json

        if (-not ($j.PSObject.Properties.Name -contains 'profiles') -or $null -eq $j.profiles) {
            $j | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        if ($j.profiles -is [System.Array]) {
            throw 'settings.json 的 profiles 是旧版数组格式，本工具不支持，请先在 Terminal 里重新生成设置'
        }
        if (-not ($j.profiles.PSObject.Properties.Name -contains 'defaults') -or $null -eq $j.profiles.defaults) {
            Set-Prop $j.profiles 'defaults' ([pscustomobject]@{})
        }

        $schemeName = 'Linux (Tango)'
        $scheme = [pscustomobject]@{
            name                = $schemeName
            background          = '#000000'
            foreground          = '#D3D7CF'
            cursorColor         = '#D3D7CF'
            selectionBackground = '#75507B'
            black               = '#2E3436'
            red                 = '#CC0000'
            green               = '#4E9A06'
            yellow              = '#C4A000'
            blue                = '#3465A4'
            purple              = '#75507B'
            cyan                = '#06989A'
            white               = '#D3D7CF'
            brightBlack         = '#555753'
            brightRed           = '#EF2929'
            brightGreen         = '#8AE234'
            brightYellow        = '#FCE94F'
            brightBlue          = '#729FCF'
            brightPurple        = '#AD7FA8'
            brightCyan          = '#34E2E2'
            brightWhite         = '#EEEEEC'
        }
        $schemes = @()
        if ($j.PSObject.Properties.Name -contains 'schemes' -and $null -ne $j.schemes) {
            $schemes = @($j.schemes | Where-Object { $null -ne $_ -and $_.name -ne $schemeName })
        }
        $schemes += $scheme
        Set-Prop $j 'schemes' $schemes

        $d = $j.profiles.defaults
        Save-DefaultsSnapshot $d
        Set-Prop $d 'colorScheme' $schemeName
        Set-Prop $d 'opacity'     $Opacity
        Set-Prop $d 'useAcrylic'  $true
        # -acrylic off：关掉磨砂亚克力，opacity 才会呈现「真透明」
        if ($Acrylic) {
            $ac = $Acrylic.Trim().ToLower()
            if ($ac -in @('on', 'true', '1', '开', '开启')) { Set-Prop $d 'useAcrylic' $true }
            elseif ($ac -in @('off', 'false', '0', '关', '关闭')) { Set-Prop $d 'useAcrylic' $false }
            else { throw "acrylic 只能是 on / off（开 / 关）" }
            Good ("亚克力: " + $(if ($ac -in @('on', 'true', '1', '开', '开启')) { '磨砂玻璃（开）' } else { '关闭（真透明）' }))
        }
        Set-Prop $d 'cursorShape' 'filledBox'
        Set-Prop $d 'padding'     '10, 8'
        Set-Prop $d 'bellStyle'   'none'
        if ($d.PSObject.Properties.Name -contains 'scrollbarState') { $d.PSObject.Properties.Remove('scrollbarState') }

        # ---- win 风格：还原成 Windows 原生观感 ----
        if ($Style -eq 'win') {
            Set-Prop $d 'colorScheme' 'Campbell'
            # 不透明度同样生效（win 默认 100，可由 -transparent 覆盖）
            Set-Prop $d 'opacity'     $Opacity
            Set-Prop $d 'useAcrylic'  $false
            if ($Acrylic) {
                $ac = $Acrylic.Trim().ToLower()
                if ($ac -in @('on', 'true', '1', '开', '开启')) { Set-Prop $d 'useAcrylic' $true }
                elseif ($ac -in @('off', 'false', '0', '关', '关闭')) { Set-Prop $d 'useAcrylic' $false }
                else { throw "acrylic 只能是 on / off（开 / 关）" }
            }
            Set-Prop $d 'cursorShape' 'bar'
            Set-Prop $d 'bellStyle'   'audible'
            if ($d.PSObject.Properties.Name -contains 'padding') { $d.PSObject.Properties.Remove('padding') }
            # Windows 原生风格不应残留自定义字体
            if ($d.PSObject.Properties.Name -contains 'font') { $d.PSObject.Properties.Remove('font') }
        }

        # ---- 高级外观：不可辨颜色修正 / 抗锯齿 / 行高 ----
        if ($AdjustColors) {
            if ($AdjustColors -notin @('never', 'indexed', 'always')) { throw "adjust-colors 取值只能是 never / indexed / always" }
            Set-Prop $d 'adjustIndistinguishableColors' $AdjustColors
        }
        if ($Antialiasing) {
            if ($Antialiasing -notin @('grayscale', 'cleartype', 'aliased')) { throw "antialiasing 取值只能是 grayscale / cleartype / aliased" }
            Set-Prop $d 'antialiasingMode' $Antialiasing
        }
        if ($CellHeight) {
            $chVal = 0.0
            if (-not [double]::TryParse($CellHeight, [ref]$chVal) -or $chVal -lt 0.8 -or $chVal -gt 2.0) {
                throw "cell-height 需要 0.8-2.0 的数字（如 1.2）"
            }
            # cellHeight 属于 font 对象内部，且类型是 CSS 长度字符串
            if (-not ($d.PSObject.Properties.Name -contains 'font') -or $null -eq $d.font) {
                Set-Prop $d 'font' ([pscustomobject]@{})
            }
            Set-Prop $d.font 'cellHeight' ([string]$chVal)
        }

        # bg-align / bg-stretch：即使当前没设背景图也要校验取值
        $alignOkList = @('bottom', 'bottomLeft', 'bottomRight', 'center', 'left', 'right', 'top', 'topLeft', 'topRight')
        $stretchOkList = @('fill', 'none', 'uniform', 'uniformToFill')
        if ($BgAlign) {
            if ($BgAlign -notin $alignOkList) { throw "bg-align 取值只能是 $($alignOkList -join ' / ')" }
            Set-Prop $d 'backgroundImageAlignment' $BgAlign
        }
        if ($BgStretch) {
            if ($BgStretch -notin $stretchOkList) { throw "bg-stretch 取值只能是 $($stretchOkList -join ' / ')" }
            Set-Prop $d 'backgroundImageStretchMode' $BgStretch
        }

        # ---- 背景图片（与窗口透明度叠加：图片透明度走 backgroundImageOpacity）----
        if ($Background -eq 'off' -or $Background -eq 'none' -or $Background -eq '') {
            if ($Background) {
                foreach ($k in @('backgroundImage', 'backgroundImageOpacity', 'backgroundImageStretchMode', 'backgroundImageAlignment')) {
                    if ($d.PSObject.Properties.Name -contains $k) { $d.PSObject.Properties.Remove($k) }
                }
                Good '背景图片已移除'
            }
        }
        else {
            if (-not (Test-Path -LiteralPath $Background)) { throw "背景图片不存在: $Background" }
            $ext = [System.IO.Path]::GetExtension($Background).ToLower()
            if ($ext -notin @('.png', '.jpg', '.jpeg', '.gif', '.bmp')) {
                throw "不支持的图片格式: $ext（支持 png/jpg/jpeg/gif/bmp）"
            }
            $bgDir = Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify'
            if ($env:WT_ADAPTIVE_DIR) { $bgDir = $env:WT_ADAPTIVE_DIR }
            if (-not (Test-Path -LiteralPath $bgDir)) { New-Item -ItemType Directory -Path $bgDir -Force | Out-Null }
            # 超大图先缩到 1920 宽：几万像素的图会让 Terminal 解码吃掉几百 MB 内存，甚至直接不渲染
            $bgSource = $Background
            $bgTemp = $null
            try {
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                $srcImg = [System.Drawing.Image]::FromFile($Background)
                $fileMB = (Get-Item -LiteralPath $Background).Length / 1MB
                if ($srcImg.Width -gt 3840 -or $fileMB -gt 8) {
                    $scale = [Math]::Min(1.0, 1920 / $srcImg.Width)
                    $nw = [int]($srcImg.Width * $scale)
                    $nh = [int]($srcImg.Height * $scale)
                    $bmp = New-Object System.Drawing.Bitmap $nw, $nh
                    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
                    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $gfx.DrawImage($srcImg, 0, 0, $nw, $nh)
                    $gfx.Dispose()
                    $srcImg.Dispose()
                    $bgTemp = Join-Path $env:TEMP ('clbt_bg_' + [guid]::NewGuid().ToString('N') + '.png')
                    $bmp.Save($bgTemp, [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmp.Dispose()
                    $bgSource = $bgTemp
                    $ext = '.png'
                    Warn ("原图过大（" + $nw + "px 缩放前 " + [int]($nw / $scale) + "px / " + [math]::Round($fileMB,1) + "MB），已自动缩放")
                }
                else { $srcImg.Dispose() }
            }
            catch { if ($bgTemp -and (Test-Path $bgTemp)) { Remove-Item $bgTemp -Force -ErrorAction SilentlyContinue } }

            # 用内容哈希命名：同一张图重跑不会「源=目标」，换图也不会覆盖 Terminal 正打开的文件
            $bgHash = (Get-FileHash -LiteralPath $bgSource -Algorithm SHA256).Hash.Substring(0, 8).ToLower()
            $bgDest = Join-Path $bgDir ('background_' + $bgHash + $ext)
            if (-not (Test-Path -LiteralPath $bgDest)) {
                Copy-Item -LiteralPath $bgSource -Destination $bgDest -Force
            }
            if ($bgTemp -and (Test-Path $bgTemp)) { Remove-Item $bgTemp -Force -ErrorAction SilentlyContinue }
            # 清理不再使用的旧背景图
            Get-ChildItem -LiteralPath $bgDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like 'background*' -and $_.FullName -ne $bgDest } |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            Set-Prop $d 'backgroundImage'            $bgDest

            # 单个配置文件里若有 backgroundImage（哪怕是 null）会覆盖 defaults，
            # 表现为「设置了背景图但某个标签页没有」，这里统一清掉
            $cleared = 0
            if ($j.profiles.PSObject.Properties.Name -contains 'list' -and $null -ne $j.profiles.list) {
                foreach ($p in @($j.profiles.list)) {
                    if ($null -ne $p -and $p.PSObject.Properties.Name -contains 'backgroundImage') {
                        $p.PSObject.Properties.Remove('backgroundImage')
                        $cleared++
                    }
                }
            }
            if ($cleared -gt 0) { Good ('已清除 ' + $cleared + ' 个配置文件上的 backgroundImage 覆盖') }
            # 图片浓淡：默认跟随窗口透明度（总不透明度 ≈ win + img*(1-win)，图太浓会盖掉透明感）
            if ($BgOpacity) {
                $imgOp = 0.0
                if (-not [double]::TryParse($BgOpacity, [ref]$imgOp) -or $imgOp -lt 0.0 -or $imgOp -gt 1.0) {
                    throw "bg-opacity 需要 0.0-1.0 之间的小数（如 0.35）"
                }
            }
            else {
                # 旧的「水印公式」= 不透明度×0.6：36% 时只有 0.22，图片几乎看不见
                # （实测画面只从 RGB(0,11,10) 变到 (63,56,32)，用户反馈"开没开一样"）
                # 改成固定 0.55：图片明显可见，又不至于盖住文字；需要更浓/更淡用 -bg-opacity
                $imgOp = 0.55
            }
            Set-Prop $d 'backgroundImageOpacity'    $imgOp
            Good ("背景图浓淡: " + $imgOp + "（窗口不透明度 " + $Opacity + "%）")
            $stretchVal = if ($BgStretch) { $BgStretch } else { 'uniformToFill' }
            if ($stretchVal -notin @('fill', 'none', 'uniform', 'uniformToFill')) { throw "bg-stretch 取值只能是 fill / none / uniform / uniformToFill" }
            $alignVal = if ($BgAlign) { $BgAlign } else { 'center' }
            $alignOk = @('bottom', 'bottomLeft', 'bottomRight', 'center', 'left', 'right', 'top', 'topLeft', 'topRight')
            if ($alignVal -notin $alignOk) { throw "bg-align 取值只能是 $($alignOk -join ' / ')" }
            Set-Prop $d 'backgroundImageStretchMode' $stretchVal
            Set-Prop $d 'backgroundImageAlignment'  $alignVal
            Good ("背景图片: " + $bgDest)
        }

        if ($Face) {
            if (-not ($d.PSObject.Properties.Name -contains 'font') -or $null -eq $d.font) {
                Set-Prop $d 'font' ([pscustomobject]@{})
            }
            Set-Prop $d.font 'face' $Face
            Set-Prop $d.font 'size' 12
        }
        if ($FontWeight) {
            if (-not ($d.PSObject.Properties.Name -contains 'font') -or $null -eq $d.font) {
                Set-Prop $d 'font' ([pscustomobject]@{})
            }
            $fw = $FontWeight.Trim().ToLower()
            if ($fw -in @('bold', '粗体')) { Set-Prop $d.font 'weight' 'bold' }
            elseif ($fw -in @('normal', 'regular', '常规', '普通')) {
                # 回到常规：直接删掉 weight，交给 Terminal 用默认字重
                if ($d.font.PSObject.Properties.Name -contains 'weight') {
                    $d.font.PSObject.Properties.Remove('weight')
                }
            }
            else { throw "font-weight 只能是 normal / bold（常规 / 粗体）" }
        }

        $json = $j | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        $styleText = if ($Style -eq 'win') { 'Campbell 配色 / 默认光标' } else { '黑色亚克力 / 方块光标 / Tango 配色' }
        Good ("外观已写入（" + $styleText + "，不透明度 " + $Opacity + "%）")
        if ($Face) { Good "字体: $Face" }
        if ($FontWeight) {
            Good ("字重: " + $(if ($fw -eq 'bold') { '粗体' } else { '常规' }))
        }
    }
    else {
        Warn '找不到 Windows Terminal 的 settings.json，跳过外观配置'
    }

    # -----------------------------------------------------------------
    # 2) 提示符与键位
    # -----------------------------------------------------------------
    Info '[2/3] 提示符与键位'

    $profileBody = @'
# =====================================================================
#  Linux 风格终端配置  ——  由 Windows 命令行美化工具生成
#  只改外观和交互，命令不变；删除本文件即可还原。
# =====================================================================

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = [Console]::OutputEncoding
} catch { }

$script:LinuxPromptIsAdmin = $false
try {
    $script:LinuxPromptIsAdmin = (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

function global:prompt {
    $e = [char]27
    $p = (Get-Location).Path
    $h = $env:USERPROFILE
    if ($p -ieq $h) {
        $p = '~'
    } elseif ($p.StartsWith($h, [StringComparison]::OrdinalIgnoreCase)) {
        $p = '~' + $p.Substring($h.Length)
    }
    $p = $p -replace '\\', '/'
    $sep = if ($script:LinuxPromptIsAdmin) { '#' } else { '$' }
    $uc = if ($script:LinuxPromptIsAdmin) { "$e[1;31m" } else { "$e[1;32m" }
    return "${uc}$($env:USERNAME)@$($env:COMPUTERNAME.ToLower())$e[0m:$e[1;34m$p$e[0m$sep "
}

try {
    if (Get-Module -ListAvailable -Name PSReadLine) {
        Import-Module PSReadLine -ErrorAction Stop

        # 键位以 Windows 习惯为基准：Ctrl+Z 撤销 / Ctrl+A 全选 / Tab 循环补全 等全部保留
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -BellStyle None
        Set-PSReadLineOption -HistorySearchCaseSensitive:$false
        Set-PSReadLineOption -MaximumHistoryCount 10000
        Set-PSReadLineOption -HistorySaveStyle SaveIncrementally

        Set-PSReadLineOption -Colors @{
            Command   = 'Green'
            Parameter = 'DarkCyan'
            Operator  = 'DarkGray'
            Variable  = 'DarkGreen'
            String    = 'DarkYellow'
            Number    = 'DarkYellow'
            Comment   = 'DarkGray'
            Keyword   = 'Cyan'
            Member    = 'DarkGray'
            Error     = 'Red'
            Selection = 'DarkCyan'
        }

        Set-PSReadLineKeyHandler -Key Ctrl+e -Function EndOfLine
        Set-PSReadLineKeyHandler -Key Ctrl+u -Function BackwardKillLine
        Set-PSReadLineKeyHandler -Key Ctrl+k -Function KillLine
        Set-PSReadLineKeyHandler -Key Ctrl+p -Function PreviousHistory
        Set-PSReadLineKeyHandler -Key Ctrl+n -Function NextHistory
        Set-PSReadLineKeyHandler -Key Alt+b  -Function BackwardWord
        Set-PSReadLineKeyHandler -Key Alt+f  -Function ForwardWord
        Set-PSReadLineKeyHandler -Key Ctrl+@ -Function MenuComplete

        if ((Get-Module PSReadLine).Version -ge [version]'2.1') {
            Set-PSReadLineOption -PredictionSource History
            Set-PSReadLineOption -PredictionViewStyle ListView
        }
    }
} catch { }

function global:ll { Get-ChildItem -Force @args }

# ---- 自适应前景色守护（由 CLBT -adaptive 安装；脚本不存在则什么都不做）----
try {
    $awPath = Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify\adaptive-watch.ps1'
    if (Test-Path -LiteralPath $awPath) {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$awPath`"") `
            -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    }
} catch { }
'@

    $targets = @()
    if ($env:WT_PROFILE_DIR) { $targets += $env:WT_PROFILE_DIR }
    else {
        $targets += (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell')
        $ps7dir = Join-Path $env:USERPROFILE 'Documents\PowerShell'
        if (Test-Path -LiteralPath $ps7dir) { $targets += $ps7dir }
    }

    if ($Style -eq 'win') {
        # 还原 PowerShell 默认提示符：只删除本工具生成的那份 profile
        foreach ($dir in $targets) {
            $prof = Join-Path $dir 'Microsoft.PowerShell_profile.ps1'
            if (Test-Path -LiteralPath $prof) {
                $txt = [System.IO.File]::ReadAllText($prof)
                if ($txt -like '*Linux 风格终端配置*') {
                    Remove-Item -LiteralPath $prof -Force
                    Good "已移除本工具生成的 profile，提示符恢复默认"
                }
                else {
                    Warn "该 profile 不是本工具生成的，未改动: $prof"
                }
            }
        }
    }
    else {
    foreach ($dir in $targets) {
        try {
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $prof = Join-Path $dir 'Microsoft.PowerShell_profile.ps1'
            if (Test-Path -LiteralPath $prof) {
                $existing = [System.IO.File]::ReadAllText($prof)
                if ($existing -notlike '*Linux 风格终端配置*') {
                    $bk = "$prof.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Copy-Item -LiteralPath $prof -Destination $bk -Force
                    Warn "已备份原有 profile: $(Split-Path -Leaf $bk)"
                }
            }
            # 必须写 UTF-8 BOM，否则中文注释会让 PowerShell 5.1 解析失败
            [System.IO.File]::WriteAllText($prof, $profileBody, (New-Object System.Text.UTF8Encoding($true)))
            Good "profile: $prof"
        }
        catch { Bad "写入 profile 失败 ($dir): $($_.Exception.Message)" }
    }
    }

    # -----------------------------------------------------------------
    # 3) 执行策略 + 字体
    # -----------------------------------------------------------------
    Info '[3/3] 执行策略与字体'

    try {
        # 本脚本以 -ExecutionPolicy Bypass 启动，不能直接问生效策略，需按作用域推导
        $mp = Get-ExecutionPolicy -Scope MachinePolicy
        $up = Get-ExecutionPolicy -Scope UserPolicy
        $cu = Get-ExecutionPolicy -Scope CurrentUser
        $lm = Get-ExecutionPolicy -Scope LocalMachine
        $effective = $null
        foreach ($v in @($mp, $up, $cu, $lm)) { if ($v -and $v -ne 'Undefined') { $effective = $v; break } }
        if (-not $effective) { $effective = 'Restricted' }

        if ($mp -in @('Restricted', 'AllSigned') -or $up -in @('Restricted', 'AllSigned')) {
            Bad "组策略强制为 $(if ($mp -ne 'Undefined') { $mp } else { $up })，profile 不会生效，需要管理员处理"
        }
        elseif ($effective -in @('Restricted', 'AllSigned')) {
            # 不替用户改安全策略（实测在 -ExecutionPolicy Bypass 子进程里改会失败，
            # 而且这类改动不该由美化工具悄悄做）。只把该跑的命令告诉他。
            Warn "PowerShell 执行策略是 $effective，profile 不会被加载（仿 Linux 提示符/键位不会生效）"
            Write-Host '       需要你自己执行一次（普通 PowerShell 窗口，不要用 -ExecutionPolicy Bypass）：' -ForegroundColor Gray
            Write-Host '         Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned' -ForegroundColor Gray
            Write-Host '      想撤回就把它改回 Restricted；本工具不会改这个设置。' -ForegroundColor DarkGray
        }
        else { Good "执行策略 $effective，profile 可正常加载" }
    }
    catch { Warn "检查执行策略失败: $($_.Exception.Message)" }

    # ---- 字体安装 ----
    $stage = Join-Path $env:TEMP ('wt_fonts_' + [guid]::NewGuid().ToString('N'))
    $fontFiles = New-Object System.Collections.ArrayList
    try {
        $emb = Expand-EmbeddedFonts $stage
        foreach ($e in $emb) { [void]$fontFiles.Add($e) }
        if ($emb.Count -gt 0) { Good "解出内嵌字体 $($emb.Count) 个" }
    } catch { Warn "读取内嵌字体失败: $($_.Exception.Message)" }

    # 只认显式 WT_FONT_DIR（例如 -font 传入的目录）；
    # 不再默认扫脚本所在目录，否则工具被解压到「含其它字体的目录」时会静默装一堆无关字体
    $extDir = $env:WT_FONT_DIR
    if ($extDir -and (Test-Path -LiteralPath $extDir)) {
        $extra = @(Get-ChildItem -LiteralPath $extDir -Filter '*.ttf' -File -ErrorAction SilentlyContinue)
        foreach ($e in $extra) { [void]$fontFiles.Add($e) }
    }

    if ($fontFiles.Count -eq 0) {
        Warn '没有可安装的字体，跳过'
    }
    elseif ($env:WT_FONT_OUT) {
        if (-not (Test-Path -LiteralPath $env:WT_FONT_OUT)) { New-Item -ItemType Directory -Path $env:WT_FONT_OUT -Force | Out-Null }
        foreach ($f in $fontFiles) { Copy-Item -LiteralPath $f.FullName -Destination $env:WT_FONT_OUT -Force }
        Good "已解出 $($fontFiles.Count) 个字体到 $($env:WT_FONT_OUT)（未安装）"
    }
    else {
        if (-not ('System.Drawing.Text.PrivateFontCollection' -as [type])) { Add-Type -AssemblyName System.Drawing }
        $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        if (-not (Test-Path -LiteralPath $userFontDir)) { New-Item -ItemType Directory -Path $userFontDir -Force | Out-Null }
        $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }

        $hkNames = @(); $cuNames = @()
        try { $hkNames = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties.Name } catch { }
        try { $cuNames = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).PSObject.Properties.Name } catch { }

        $installed = 0; $skipped = 0
        foreach ($f in $fontFiles) {
            try {
                $fam = Get-FamilyOf $f.FullName $f.BaseName
                $style = Get-FontStyleOf $f.BaseName
                $regName = if ($style -eq 'Regular') { "$fam (TrueType)" } else { "$fam $style (TrueType)" }

                # 已注册（系统级或用户级）就跳过，避免重复
                if (($hkNames -contains $regName) -or ($cuNames -contains $regName)) { $skipped++; continue }

                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $userFontDir $f.Name) -Force
                New-ItemProperty -Path $reg -Name $regName -Value (Join-Path $userFontDir $f.Name) -PropertyType String -Force | Out-Null
                $installed++
            }
            catch { Bad "字体 $($f.Name) 安装失败: $($_.Exception.Message)" }
        }
        Good "字体：新安装 $installed 个，已存在跳过 $skipped 个（按当前用户，无需管理员）"
    }

    # ---- cmd（命令提示符）的仿 Linux 提示符 ----
    if ($env:WT_CMDPROMPT -eq '1') {
        try {
            Install-CmdPrompt
            Good 'cmd 提示符：已写入 AutoRun（新开的 cmd 生效）'
        }
        catch { Warn "设置 cmd 提示符失败: $($_.Exception.Message)" }
    }
    else {
        Write-Host '  [--]   cmd 提示符：保持原样（仅 PowerShell）' -ForegroundColor DarkGray
    }

    if ($stage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
}

# =====================================================================
# cmd（命令提示符）的仿 Linux 提示符
#   原理：cmd 没有 profile，只能通过 HKCU 的 AutoRun 在启动时注入。
#   只写当前用户（HKCU），且若已有 AutoRun 值会「追加」而不是覆盖。
# =====================================================================
$CmdPromptBody = @'
@echo off
rem  Linux-style prompt for cmd.exe (generated by terminal-setup.cmd)
rem  Invoked via  HKCU\Software\Microsoft\Command Processor\AutoRun
rem  Remove: run  terminal-setup.cmd --undo-cmd
setlocal EnableDelayedExpansion
if not defined USERPROFILE goto :wt_done

set "wt_u=!USERNAME!"
set "wt_h=!COMPUTERNAME!"
set "wt_h=!wt_h:A=a!"
set "wt_h=!wt_h:B=b!"
set "wt_h=!wt_h:C=c!"
set "wt_h=!wt_h:D=d!"
set "wt_h=!wt_h:E=e!"
set "wt_h=!wt_h:F=f!"
set "wt_h=!wt_h:G=g!"
set "wt_h=!wt_h:H=h!"
set "wt_h=!wt_h:I=i!"
set "wt_h=!wt_h:J=j!"
set "wt_h=!wt_h:K=k!"
set "wt_h=!wt_h:L=l!"
set "wt_h=!wt_h:M=m!"
set "wt_h=!wt_h:N=n!"
set "wt_h=!wt_h:O=o!"
set "wt_h=!wt_h:P=p!"
set "wt_h=!wt_h:Q=q!"
set "wt_h=!wt_h:R=r!"
set "wt_h=!wt_h:S=s!"
set "wt_h=!wt_h:T=t!"
set "wt_h=!wt_h:U=u!"
set "wt_h=!wt_h:V=v!"
set "wt_h=!wt_h:W=w!"
set "wt_h=!wt_h:X=x!"
set "wt_h=!wt_h:Y=y!"
set "wt_h=!wt_h:Z=z!"
set "wt_p=!CD!"

set "wt_s=!USERPROFILE!"
set /a wt_n=0
:wt_len
if not defined wt_s goto :wt_len_done
set "wt_s=!wt_s:~1!"
set /a wt_n+=1
goto :wt_len

:wt_len_done
if /i "!wt_p!"=="!USERPROFILE!" (
    set "wt_p=~"
) else (
    if /i "!wt_p:~0,%wt_n%!"=="!USERPROFILE!" set "wt_p=~!wt_p:~%wt_n%!"
)
set "wt_p=!wt_p:\=/!"

set "wt_P=$E[1;32m!wt_u!@!wt_h!$E[0m:$E[1;34m!wt_p!$E[0m$$ "
endlocal & set "PROMPT=%wt_P%"
:wt_done
'@

function Get-CmdPromptPath {
    return (Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify\cmd-prompt.cmd')
}

function Install-CmdPrompt {
    $dir = Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cmdScript = Get-CmdPromptPath

    # 批处理必须以 CRLF 写入，且内容为纯 ASCII
    $body = ($CmdPromptBody -replace "`r`n", "`n") -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($cmdScript, $body, (New-Object System.Text.UTF8Encoding($false)))

    $key = 'HKCU:\Software\Microsoft\Command Processor'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

    $cur = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    # 只摘掉指向本工具 cmd-prompt.cmd 的那一段，不按 & 切分（别人引号里的 & 不能被掰断）
    $rest = Remove-OurAutoRun $cur
    $newVal = if ($rest) { $rest + ' & ' + ('call "' + $cmdScript + '"') } else { ('call "' + $cmdScript + '"') }
    New-ItemProperty -Path $key -Name AutoRun -Value $newVal -PropertyType String -Force | Out-Null
}

function Remove-OurAutoRun([string]$cur) {
    # 从 AutoRun 里摘掉本工具那一段：call "...cmd-prompt.cmd" 及其前后多余的 &
    if (-not $cur) { return $null }
    $pat = '(?i)(\s*&\s*)?call\s+"[^"]*cmd-prompt\.cmd"\s*(&\s*)?'
    $r = [regex]::Replace($cur, $pat, ' ')
    $r = $r -replace '(\s*&\s*){2,}', ' & '        # 合并空段
    $r = $r.Trim()
    $r = $r -replace '^\s*&\s*', '' -replace '\s*&\s*$', ''
    if ([string]::IsNullOrWhiteSpace($r)) { return $null }
    return $r
}

function Remove-CmdPrompt {
    $key = 'HKCU:\Software\Microsoft\Command Processor'
    $cur = (Get-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    if ($cur) {
        $rest = Remove-OurAutoRun $cur
        if ($rest) {
            Set-ItemProperty -Path $key -Name AutoRun -Value $rest
        } else {
            Remove-ItemProperty -Path $key -Name AutoRun -ErrorAction SilentlyContinue
        }
    }
    $cmdScript = Get-CmdPromptPath
    if (Test-Path -LiteralPath $cmdScript) { Remove-Item -LiteralPath $cmdScript -Force -ErrorAction SilentlyContinue }
    $dir = Split-Path -Parent $cmdScript
    if ((Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
    }
}

# =====================================================================
# 代码页：让 cmd 标签以 UTF-8 启动，避免运行 UTF-8 编码的 .bat 时中文乱码
#   原理：Terminal 的 cmd 配置文件 commandline 改成
#         cmd.exe /k chcp 65001 >nul
#   注意：这只影响 Terminal 里的 cmd 标签，不动系统全局 AutoRun。
# =====================================================================
function Set-EncodingMode([bool]$On) {
    $sp = $env:WT_SETTINGS_PATH
    if (-not $sp) {
        $cands = @(
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
        )
        $sp = $cands | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $sp -or -not (Test-Path -LiteralPath $sp)) { Warn '找不到 settings.json，跳过编码设置'; return }

    $backup = "$sp.bak-encoding-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $sp -Destination $backup -Force

    $raw = [System.IO.File]::ReadAllText($sp, [System.Text.UTF8Encoding]::new($false))
    $j = (Strip-JsonComments $raw) | ConvertFrom-Json
    if (-not ($j.PSObject.Properties.Name -contains 'profiles') -or $null -eq $j.profiles -or
        -not ($j.profiles.PSObject.Properties.Name -contains 'list') -or $null -eq $j.profiles.list) {
        Warn 'settings.json 里没有 profiles.list，跳过'; return
    }

    $changed = 0
    foreach ($prof in @($j.profiles.list)) {
        if ($null -eq $prof) { continue }
        $cl = [string]$prof.commandline
        if ($cl -notmatch 'cmd\.exe') { continue }

        # 先清掉本工具之前加的那段（行尾追加式 / 行内 & 式都清），避免重复叠加
        $clean = $cl -replace '\s*/k\s+chcp\s+65001\s*>\s*nul\s*$', ''
        $clean = $clean -replace '(?i)chcp\s+65001\s*>\s*nul\s*&\s*', ''
        if ($On) {
            $base = $clean.TrimEnd()
            $kIdx = $base.IndexOf('/k ', [System.StringComparison]::OrdinalIgnoreCase)
            if ($kIdx -ge 0) {
                # 已有 /k：把 chcp 插进同一条启动命令（cmd 只认第一个 /k，不能追加第二个）
                $insertAt = $kIdx + 3
                $prof.commandline = $base.Substring(0, $insertAt) + 'chcp 65001 >nul & ' +
                    $base.Substring($insertAt).TrimStart()
            }
            else {
                $prof.commandline = ($base + ' /k chcp 65001 >nul')
            }
        }
        else {
            $prof.commandline = $clean.TrimEnd()
        }
        $changed++
    }

    if ($changed -eq 0) { Warn '没有找到 cmd 配置文件，跳过'; return }

    $json = $j | ConvertTo-Json -Depth 32
    [System.IO.File]::WriteAllText($sp, $json, (New-Object System.Text.UTF8Encoding($false)))
    if ($On) { Good ('已让 ' + $changed + ' 个 cmd 配置以 UTF-8 启动（chcp 65001）') }
    else { Good ('已还原 ' + $changed + ' 个 cmd 配置的代码页设置') }
}

# =====================================================================
# 撤回：把终端外观、提示符、cmd 挂钩还原成 Windows 默认
#   注意：这是「撤回对命令行的修改」，不删除 CLBT 本体，也不动 PATH；
#         卸载命令本身请用 install.exe --uninstall / install.py --uninstall
# =====================================================================
function Invoke-Uninstall {
    $done = @()

    # ---- 1) 终端外观 ----
    $settingsPath = $env:WT_SETTINGS_PATH
    if (-not $settingsPath) {
        $cands = @(
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal Preview\settings.json')
        )
        $settingsPath = $cands | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }

    if ($settingsPath -and (Test-Path -LiteralPath $settingsPath)) {
        $backup = "$settingsPath.bak-uninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $settingsPath -Destination $backup -Force
        $raw = [System.IO.File]::ReadAllText($settingsPath, [System.Text.UTF8Encoding]::new($false))
        $j = (Strip-JsonComments $raw) | ConvertFrom-Json

        if ($j.PSObject.Properties.Name -contains 'profiles' -and $null -ne $j.profiles -and
            $j.profiles.PSObject.Properties.Name -contains 'defaults' -and $null -ne $j.profiles.defaults) {
            $d = $j.profiles.defaults

            # 还原为 Windows Terminal 默认值
            Set-Prop $d 'colorScheme' 'Campbell'
            Set-Prop $d 'opacity'     100
            Set-Prop $d 'useAcrylic'  $false
            Set-Prop $d 'cursorShape' 'bar'
            Set-Prop $d 'bellStyle'   'audible'
            foreach ($k in @('padding', 'scrollbarState', 'backgroundImage', 'backgroundImageOpacity', 'backgroundImageStretchMode', 'backgroundImageAlignment')) {
                if ($d.PSObject.Properties.Name -contains $k) { $d.PSObject.Properties.Remove($k) }
            }
            if ($d.PSObject.Properties.Name -contains 'font') { $d.PSObject.Properties.Remove('font') }

            # 还原用户原先自己配的字体/内边距/滚动条
            try {
                $snapFile = Join-Path (Get-AdaptiveDir) 'defaults-snapshot.json'
                if (Test-Path -LiteralPath $snapFile) {
                    $snap = (Get-Content -LiteralPath $snapFile -Raw -Encoding UTF8) | ConvertFrom-Json
                    foreach ($pp in $snap.PSObject.Properties) { Set-Prop $d $pp.Name $pp.Value }
                    Remove-Item -LiteralPath $snapFile -Force -ErrorAction SilentlyContinue
                    $done += '已还原你原先的字体/内边距/滚动条设置'
                }
            }
            catch { }


            # 移除本工具新增的配色方案
            if ($j.PSObject.Properties.Name -contains 'schemes' -and $null -ne $j.schemes) {
                $rest = @($j.schemes | Where-Object { $null -ne $_ -and $_.name -ne 'Linux (Tango)' })
                Set-Prop $j 'schemes' $rest
            }

            foreach ($k in @('adjustIndistinguishableColors', 'antialiasingMode')) {
                if ($d.PSObject.Properties.Name -contains $k) { $d.PSObject.Properties.Remove($k) }
            }
            # 先改内存里的命令行，最后再一次性写盘（否则改动永远落不了盘）
            foreach ($prof in @($j.profiles.list)) {
                if ($null -ne $prof -and ([string]$prof.commandline) -match 'chcp\s+65001') {
                    $c1 = [string]$prof.commandline
                    $c1 = $c1 -replace '\s*/k\s+chcp\s+65001\s*>\s*nul\s*$', ''
                    $c1 = $c1 -replace '(?i)chcp\s+65001\s*>\s*nul\s*&\s*', ''
                    $prof.commandline = $c1.TrimEnd()
                    $done += '已还原 cmd 标签的代码页设置'
                }
            }
            $json = $j | ConvertTo-Json -Depth 32
            [System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))
            $done += '终端外观已还原（Campbell / 不透明 / 默认光标与字体）'

            $bgDir2 = Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify'
            if ($env:WT_ADAPTIVE_DIR) { $bgDir2 = $env:WT_ADAPTIVE_DIR }
            $removed = 0
            Get-ChildItem -LiteralPath $bgDir2 -File -Filter 'background*' -ErrorAction SilentlyContinue |
                ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue; $removed++ }
            if ($removed -gt 0) { $done += ('已删除复制的背景图片 ' + $removed + ' 个') }
        }
    }

    # ---- 2) PowerShell 提示符 ----
    $targets = @()
    if ($env:WT_PROFILE_DIR) { $targets += $env:WT_PROFILE_DIR }
    else {
        $targets += (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell')
        $ps7 = Join-Path $env:USERPROFILE 'Documents\PowerShell'
        if (Test-Path -LiteralPath $ps7) { $targets += $ps7 }
    }
    foreach ($dir in $targets) {
        $prof = Join-Path $dir 'Microsoft.PowerShell_profile.ps1'
        if (Test-Path -LiteralPath $prof) {
            $txt = [System.IO.File]::ReadAllText($prof)
            if ($txt -like '*Linux 风格终端配置*') {
                Remove-Item -LiteralPath $prof -Force
                $done += 'PowerShell 提示符已恢复默认（删除本工具生成的 profile）'
            }
            else {
                $done += 'profile 不是本工具生成的，已保留'
            }
        }
    }

    # ---- 3) 自适应守护 ----
    try {
        $awPath = Join-Path (Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify') 'adaptive-watch.ps1'
        if ($env:WT_ADAPTIVE_DIR) { $awPath = Join-Path $env:WT_ADAPTIVE_DIR 'adaptive-watch.ps1' }
        if (Test-Path -LiteralPath $awPath) {
            Remove-Adaptive
            $done += '自适应守护已停止并清理'
        }
    } catch {
        $done += ('自适应清理失败: ' + $_.Exception.Message)
    }

    # ---- 4) cmd 挂钩 ----
    try {
        Remove-CmdPrompt
        $done += 'cmd 提示符挂钩已移除（AutoRun 已还原）'
    } catch {
        $done += ('cmd 挂钩移除失败: ' + $_.Exception.Message)
    }

    foreach ($x in $done) { Good $x }
    Write-Host ''
    Write-Host '  说明：字体（.ttf 文件）与应用本身未删除；如需彻底卸载请运行 install.exe --uninstall' -ForegroundColor DarkGray
}

# =====================================================================
# 自检：本文件必须是 CRLF 行尾。若是 LF，cmd 可能把内嵌正文当命令执行，
# 表现为一堆「不是内部或外部命令」的错误。
# =====================================================================
try {
    $fs = [System.IO.File]::OpenRead($env:WT_SELF)
    $buf = New-Object byte[] 8192
    $n = $fs.Read($buf, 0, 8192)
    $fs.Close()
    $head = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
    if ($head.Contains("`n") -and -not $head.Contains("`r`n")) {
        Write-Host '  [!!] 检测到本文件是 LF 行尾（应为 CRLF）。' -ForegroundColor Yellow
        Write-Host '       这会导致 cmd 误解析内嵌脚本，建议重新获取原始文件。' -ForegroundColor Yellow
        Write-Host '' -ForegroundColor DarkGray
    }
}
catch { }

# =====================================================================
# 自适应前景色守护：窗口透明时按背景明暗自动切换字体深浅
#   守护脚本以 base64 内嵌（脚本自身含 here-string，无法直接嵌套）
# =====================================================================
$AdaptiveWatchB64 = @'
77u/IyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT0NCiMgIOiHqumAguW6lOWJjeaZr+iJsuWuiOaKpOi/m+eoiw0KIyAg
5b2T56qX5Y+j6Laz5aSf6YCP5piO77yI5LiN6YCP5piO5bqmIDwgNzUl77yJ5pe277yM5a6e5pe2
6YeH5qC357uI56uv56qX5Y+j5ZGo5Zu055qE5YOP57Sg77yaDQojICAgIMK3IOS6ruiDjOaZryAt
PiDnlKjmt7HoibLmloflrZcNCiMgICAgwrcg5pqX6IOM5pmvIC0+IOeUqOa1heiJsuaWh+Wtlw0K
IyAg5Y+q5Zyo44CM5Yik5pat57uT5p6c5Y+R55Sf5Y+Y5YyW44CN5pe25omN5pS55YaZIHNldHRp
bmdzLmpzb27vvIhUZXJtaW5hbCDkvJrng63liqDovb3vvIkNCiMNCiMgIOeUqOazle+8mnBvd2Vy
c2hlbGwgLU5vUHJvZmlsZSAtRmlsZSBhZGFwdGl2ZS13YXRjaC5wczEgWy1PbmNlXSBbLUZvcmNl
THVtIDAtMjU1XQ0KIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT0NCnBhcmFtKA0KICAgIFtzdHJpbmddJFNldHRpbmdz
UGF0aCA9ICcnLA0KICAgIFtpbnRdJEludGVydmFsTXMgPSAyMDAwLA0KICAgIFtpbnRdJFRocmVz
aG9sZCA9IDEyOCwgICAgICAgICMg5oSf55+l5Lqu5bqm6auY5LqO5q2k5YC86KeG5Li6IuS6ruiD
jOaZryINCiAgICBbaW50XSRGb3JjZUx1bSA9IC0xLCAgICAgICAgICAjIOa1i+ivleeUqO+8muW8
uuWItuS6ruW6pu+8jOi3s+i/h+mHh+agtw0KICAgIFtzd2l0Y2hdJE9uY2UsICAgICAgICAgICAg
ICAgICMg5Y+q6LeR5LiA6L2u77yI5rWL6K+V55So77yJDQogICAgW3N3aXRjaF0kUHJvYmUsICAg
ICAgICAgICAgICAgIyDlj6rph4fmoLflubbmiZPljbDkuq7luqbvvIzkuI3lhpnphY3nva4NCiAg
ICBbaW50XSRNYXhJZGxlU2VjID0gNjAgICAgICAgICAjIOi/nue7rei/meS5iOWkmuenkuaJvuS4
jeWIsOe7iOerr+eql+WPo+WwsemAgOWHug0KKQ0KDQokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0g
J1N0b3AnDQokTE9DS19OQU1FID0gJ0dsb2JhbFxDTEJUX0FkYXB0aXZlV2F0Y2gnDQoNCiMgLS0t
LSDliY3mma/oibLlrprkuYkgLS0tLQ0KJEZHX0xJR0hUID0gJyNEM0Q3Q0YnICAgIyDmmpfog4zm
ma/nlKjmtYXoibLlrZfvvIjpu5jorqQgVGFuZ28g5YmN5pmv77yJDQokRkdfREFSSyAgPSAnIzE0
MTYxQScgICAjIOS6ruiDjOaZr+eUqOa3seiJsuWtlw0KJFNDSEVNRSAgID0gJ0xpbnV4IChUYW5n
byknDQoNCkFkZC1UeXBlIC1Bc3NlbWJseU5hbWUgU3lzdGVtLkRyYXdpbmcNCkFkZC1UeXBlIC1U
eXBlRGVmaW5pdGlvbiBAJw0KdXNpbmcgU3lzdGVtOw0KdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50
ZXJvcFNlcnZpY2VzOw0KcHVibGljIGNsYXNzIEFXIHsNCiAgICBbU3RydWN0TGF5b3V0KExheW91
dEtpbmQuU2VxdWVudGlhbCldIHB1YmxpYyBzdHJ1Y3QgUkVDVCB7IHB1YmxpYyBpbnQgTGVmdCwg
VG9wLCBSaWdodCwgQm90dG9tOyB9DQogICAgW0RsbEltcG9ydCgidXNlcjMyLmRsbCIpXSBwdWJs
aWMgc3RhdGljIGV4dGVybiBib29sIEdldFdpbmRvd1JlY3QoSW50UHRyIGgsIG91dCBSRUNUIHIp
Ow0KICAgIFtEbGxJbXBvcnQoInVzZXIzMi5kbGwiKV0gcHVibGljIHN0YXRpYyBleHRlcm4gSW50
UHRyIEdldEZvcmVncm91bmRXaW5kb3coKTsNCiAgICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIild
IHB1YmxpYyBzdGF0aWMgZXh0ZXJuIGJvb2wgSXNXaW5kb3dWaXNpYmxlKEludFB0ciBoKTsNCiAg
ICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIildIHB1YmxpYyBzdGF0aWMgZXh0ZXJuIGJvb2wgSXNJ
Y29uaWMoSW50UHRyIGgpOw0KfQ0KJ0ANCg0KZnVuY3Rpb24gR2V0LVNldHRpbmdzUGF0aCB7DQog
ICAgaWYgKCRTZXR0aW5nc1BhdGgpIHsgcmV0dXJuICRTZXR0aW5nc1BhdGggfQ0KICAgIGlmICgk
ZW52OldUX1NFVFRJTkdTX1BBVEgpIHsgcmV0dXJuICRlbnY6V1RfU0VUVElOR1NfUEFUSCB9DQog
ICAgJGMgPSBAKA0KICAgICAgICAoSm9pbi1QYXRoICRlbnY6TE9DQUxBUFBEQVRBICdQYWNrYWdl
c1xNaWNyb3NvZnQuV2luZG93c1Rlcm1pbmFsXzh3ZWt5YjNkOGJid2VcTG9jYWxTdGF0ZVxzZXR0
aW5ncy5qc29uJyksDQogICAgICAgIChKb2luLVBhdGggJGVudjpMT0NBTEFQUERBVEEgJ1BhY2th
Z2VzXE1pY3Jvc29mdC5XaW5kb3dzVGVybWluYWxQcmV2aWV3Xzh3ZWt5YjNkOGJid2VcTG9jYWxT
dGF0ZVxzZXR0aW5ncy5qc29uJyksDQogICAgICAgIChKb2luLVBhdGggJGVudjpMT0NBTEFQUERB
VEEgJ01pY3Jvc29mdFxXaW5kb3dzIFRlcm1pbmFsXHNldHRpbmdzLmpzb24nKQ0KICAgICkNCiAg
ICByZXR1cm4gKCRjIHwgV2hlcmUtT2JqZWN0IHsgVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkXyB9
IHwgU2VsZWN0LU9iamVjdCAtRmlyc3QgMSkNCn0NCg0KZnVuY3Rpb24gR2V0LUZpbGVKc29uKFtz
dHJpbmddJHBhdGgpIHsNCiAgICAkcmF3ID0gW1N5c3RlbS5JTy5GaWxlXTo6UmVhZEFsbFRleHQo
JHBhdGgsIFtTeXN0ZW0uVGV4dC5VVEY4RW5jb2RpbmddOjpuZXcoJGZhbHNlKSkNCiAgICAjIOWO
u+aOiSAvLyDkuI4gLyogKi8g5rOo6YeK77yI5L+d55WZ5a2X56ym5Liy5YaF55qEIC8v77yJDQog
ICAgJHNiID0gTmV3LU9iamVjdCBTeXN0ZW0uVGV4dC5TdHJpbmdCdWlsZGVyDQogICAgJGluU3Ry
ID0gJGZhbHNlOyAkZXNjID0gJGZhbHNlOyAkaSA9IDANCiAgICB3aGlsZSAoJGkgLWx0ICRyYXcu
TGVuZ3RoKSB7DQogICAgICAgICRjaCA9ICRyYXdbJGldDQogICAgICAgIGlmICgkaW5TdHIpIHsN
CiAgICAgICAgICAgIFt2b2lkXSRzYi5BcHBlbmQoJGNoKQ0KICAgICAgICAgICAgaWYgKCRlc2Mp
IHsgJGVzYyA9ICRmYWxzZSB9DQogICAgICAgICAgICBlbHNlaWYgKCRjaCAtZXEgJ1wnKSB7ICRl
c2MgPSAkdHJ1ZSB9DQogICAgICAgICAgICBlbHNlaWYgKCRjaCAtZXEgJyInKSB7ICRpblN0ciA9
ICRmYWxzZSB9DQogICAgICAgICAgICAkaSsrDQogICAgICAgIH0NCiAgICAgICAgZWxzZWlmICgk
Y2ggLWVxICciJykgeyAkaW5TdHIgPSAkdHJ1ZTsgW3ZvaWRdJHNiLkFwcGVuZCgkY2gpOyAkaSsr
IH0NCiAgICAgICAgZWxzZWlmICgkY2ggLWVxICcvJyAtYW5kICgkaSArIDEpIC1sdCAkcmF3Lkxl
bmd0aCAtYW5kICRyYXdbJGkgKyAxXSAtZXEgJy8nKSB7DQogICAgICAgICAgICB3aGlsZSAoJGkg
LWx0ICRyYXcuTGVuZ3RoIC1hbmQgJHJhd1skaV0gLW5lICJgbiIpIHsgJGkrKyB9DQogICAgICAg
IH0NCiAgICAgICAgZWxzZWlmICgkY2ggLWVxICcvJyAtYW5kICgkaSArIDEpIC1sdCAkcmF3Lkxl
bmd0aCAtYW5kICRyYXdbJGkgKyAxXSAtZXEgJyonKSB7DQogICAgICAgICAgICAkaSArPSAyDQog
ICAgICAgICAgICB3aGlsZSAoKCRpICsgMSkgLWx0ICRyYXcuTGVuZ3RoIC1hbmQgLW5vdCAoJHJh
d1skaV0gLWVxICcqJyAtYW5kICRyYXdbJGkgKyAxXSAtZXEgJy8nKSkgeyAkaSsrIH0NCiAgICAg
ICAgICAgICRpICs9IDINCiAgICAgICAgfQ0KICAgICAgICBlbHNlIHsgW3ZvaWRdJHNiLkFwcGVu
ZCgkY2gpOyAkaSsrIH0NCiAgICB9DQogICAgcmV0dXJuICgkc2IuVG9TdHJpbmcoKSB8IENvbnZl
cnRGcm9tLUpzb24pDQp9DQoNCmZ1bmN0aW9uIEdldC1UZXJtaW5hbFJlY3Qgew0KICAgICMg5Y+W
5b2T5YmN5YmN5Y+w56qX5Y+j77yb6Iul5a6D5YOP57uI56uv77yI6auY5a695q+U5ZCI55CG5LiU
5Y+v6KeB77yJ5bCx55So5a6DDQogICAgJGggPSBbQVddOjpHZXRGb3JlZ3JvdW5kV2luZG93KCkN
CiAgICBpZiAoJGggLWVxIFtJbnRQdHJdOjpaZXJvKSB7IHJldHVybiAkbnVsbCB9DQogICAgJHIg
PSBOZXctT2JqZWN0IEFXK1JFQ1QNCiAgICBpZiAoLW5vdCBbQVddOjpHZXRXaW5kb3dSZWN0KCRo
LCBbcmVmXSRyKSkgeyByZXR1cm4gJG51bGwgfQ0KICAgICR3ID0gJHIuUmlnaHQgLSAkci5MZWZ0
OyAkaHQgPSAkci5Cb3R0b20gLSAkci5Ub3ANCiAgICBpZiAoJHcgLWx0IDIwMCAtb3IgJGh0IC1s
dCAxNTApIHsgcmV0dXJuICRudWxsIH0NCiAgICByZXR1cm4gW3BzY3VzdG9tb2JqZWN0XUB7IEh3
bmQgPSAkaDsgTGVmdCA9ICRyLkxlZnQ7IFRvcCA9ICRyLlRvcDsgUmlnaHQgPSAkci5SaWdodDsg
Qm90dG9tID0gJHIuQm90dG9tOyBXID0gJHc7IEggPSAkaHQgfQ0KfQ0KDQpmdW5jdGlvbiBHZXQt
QmFja2Ryb3BMdW1pbmFuY2UoJHJlY3QpIHsNCiAgICAjIOmHh+agt+eql+WPo+WkluWciOS4gOWc
iOWDj+e0oO+8iOahjOmdoi/lhbblroPnqpflj6PvvInvvIznlKjmnaXmjqjmlq3lvZPliY3ljLrl
n5/nmoTmmI7mmpfjgIINCiAgICAjIOe7iOerr+acrOi6q+S4jemAj+aYjuWcsOeUu+iHquW3seea
hOWGheWuue+8jOaJgOS7peS4jeiDveS7jueql+WPo+WGhemDqOWPluiDjOaZr+OAgg0KICAgICRi
YW5kID0gMTQNCiAgICAkYm1wID0gTmV3LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5CaXRtYXAgMjIw
LCA2MA0KICAgICRnID0gW1N5c3RlbS5EcmF3aW5nLkdyYXBoaWNzXTo6RnJvbUltYWdlKCRibXAp
DQogICAgJHN1bUwgPSAwOyAkbiA9IDANCg0KICAgIHRyeSB7DQogICAgICAgICMg5bem5L6n5LiO
5Y+z5L6n56uW5p2hDQogICAgICAgIGZvcmVhY2ggKCR4IGluIEAoKCRyZWN0LkxlZnQgLSAkYmFu
ZCksICgkcmVjdC5SaWdodCArICRiYW5kKSkpIHsNCiAgICAgICAgICAgIGZvciAoJGsgPSAwOyAk
ayAtbHQgNjsgJGsrKykgew0KICAgICAgICAgICAgICAgICR5ID0gJHJlY3QuVG9wICsgW2ludF0o
JHJlY3QuSCAqICgkayArIDAuNSkgLyA2KQ0KDQogICAgICAgICAgICAgICAgdHJ5IHsNCiAgICAg
ICAgICAgICAgICAgICAgJGcuQ29weUZyb21TY3JlZW4oJHgsICR5LCAkayAqIDIwLCAwLCAoTmV3
LU9iamVjdCBTeXN0ZW0uRHJhd2luZy5TaXplIDEyLCA4KSkNCiAgICAgICAgICAgICAgICAgICAg
JGMgPSAkYm1wLkdldFBpeGVsKCRrICogMjAgKyA0LCAzKQ0KICAgICAgICAgICAgICAgICAgICAk
c3VtTCArPSAoMC4yOTkgKiAkYy5SICsgMC41ODcgKiAkYy5HICsgMC4xMTQgKiAkYy5CKQ0KICAg
ICAgICAgICAgICAgICAgICAkbisrDQogICAgICAgICAgICAgICAgfSBjYXRjaCB7IH0NCiAgICAg
ICAgICAgIH0NCiAgICAgICAgfQ0KICAgICAgICAjIOS4iuaWueS4juS4i+aWueaoquadoQ0KICAg
ICAgICBmb3JlYWNoICgkeSBpbiBAKCgkcmVjdC5Ub3AgLSAkYmFuZCksICgkcmVjdC5Cb3R0b20g
KyAkYmFuZCkpKSB7DQogICAgICAgICAgICBmb3IgKCRrID0gMDsgJGsgLWx0IDY7ICRrKyspIHsN
CiAgICAgICAgICAgICAgICAkeCA9ICRyZWN0LkxlZnQgKyBbaW50XSgkcmVjdC5XICogKCRrICsg
MC41KSAvIDYpDQogICAgICAgICAgICAgICAgdHJ5IHsNCiAgICAgICAgICAgICAgICAgICAgJGcu
Q29weUZyb21TY3JlZW4oJHgsICR5LCAkayAqIDIwLCAyMCwgKE5ldy1PYmplY3QgU3lzdGVtLkRy
YXdpbmcuU2l6ZSAxMiwgOCkpDQogICAgICAgICAgICAgICAgICAgICRjID0gJGJtcC5HZXRQaXhl
bCgkayAqIDIwICsgNCwgMjMpDQogICAgICAgICAgICAgICAgICAgICRzdW1MICs9ICgwLjI5OSAq
ICRjLlIgKyAwLjU4NyAqICRjLkcgKyAwLjExNCAqICRjLkIpDQogICAgICAgICAgICAgICAgICAg
ICRuKysNCiAgICAgICAgICAgICAgICB9IGNhdGNoIHsgfQ0KICAgICAgICAgICAgfQ0KICAgICAg
ICB9DQogICAgfSBmaW5hbGx5IHsgJGcuRGlzcG9zZSgpOyAkYm1wLkRpc3Bvc2UoKSB9DQoNCiAg
ICBpZiAoJG4gLWVxIDApIHsgcmV0dXJuIC0xIH0NCiAgICByZXR1cm4gW2ludF0oJHN1bUwgLyAk
bikNCn0NCg0KZnVuY3Rpb24gR2V0LU9wYWNpdHkoJGpzb24pIHsNCiAgICB0cnkgew0KICAgICAg
ICAkbyA9ICRqc29uLnByb2ZpbGVzLmRlZmF1bHRzLm9wYWNpdHkNCiAgICAgICAgaWYgKCRudWxs
IC1lcSAkbykgeyByZXR1cm4gMTAwIH0NCiAgICAgICAgcmV0dXJuIFtpbnRdJG8NCiAgICB9IGNh
dGNoIHsgcmV0dXJuIDEwMCB9DQp9DQoNCmZ1bmN0aW9uIFNldC1Gb3JlZ3JvdW5kKFtzdHJpbmdd
JHBhdGgsICRqc29uLCBbc3RyaW5nXSRjb2xvckhleCkgew0KICAgICRjaGFuZ2VkID0gJGZhbHNl
DQogICAgZm9yZWFjaCAoJHMgaW4gQCgkanNvbi5zY2hlbWVzKSkgew0KICAgICAgICBpZiAoJG51
bGwgLW5lICRzIC1hbmQgJHMubmFtZSAtZXEgJFNDSEVNRSkgew0KICAgICAgICAgICAgaWYgKCRz
LmZvcmVncm91bmQgLW5lICRjb2xvckhleCkgeyAkcy5mb3JlZ3JvdW5kID0gJGNvbG9ySGV4OyAk
Y2hhbmdlZCA9ICR0cnVlIH0NCiAgICAgICAgfQ0KICAgIH0NCiAgICAjIGN1cnNvckNvbG9yIOi3
n+maj++8jOmBv+WFjea3seiJsuWtl+mFjea1heiJsuWFieaghw0KICAgIGZvcmVhY2ggKCRzIGlu
IEAoJGpzb24uc2NoZW1lcykpIHsNCiAgICAgICAgaWYgKCRudWxsIC1uZSAkcyAtYW5kICRzLm5h
bWUgLWVxICRTQ0hFTUUpIHsNCiAgICAgICAgICAgIGlmICgkcy5jdXJzb3JDb2xvciAtbmUgJGNv
bG9ySGV4KSB7ICRzLmN1cnNvckNvbG9yID0gJGNvbG9ySGV4OyAkY2hhbmdlZCA9ICR0cnVlIH0N
CiAgICAgICAgfQ0KICAgIH0NCiAgICBpZiAoJGNoYW5nZWQpIHsNCiAgICAgICAgJG91dCA9ICRq
c29uIHwgQ29udmVydFRvLUpzb24gLURlcHRoIDMyDQogICAgICAgICMg5Y6f5a2Q5YaZ5YWl77ya
5YWI5YaZ5Li05pe25paH5Lu25YaN5pu/5o2i77yM6YG/5YWNIFRlcm1pbmFsIOivu+WIsOWNiuaI
qiBKU09ODQogICAgICAgICR0bXAgPSAkcGF0aCArICcuY2xidC10bXAnDQogICAgICAgIFtTeXN0
ZW0uSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkdG1wLCAkb3V0LCAoTmV3LU9iamVjdCBTeXN0ZW0u
VGV4dC5VVEY4RW5jb2RpbmcoJGZhbHNlKSkpDQogICAgICAgIHRyeSB7DQogICAgICAgICAgICBb
U3lzdGVtLklPLkZpbGVdOjpSZXBsYWNlKCR0bXAsICRwYXRoLCAkbnVsbCkNCiAgICAgICAgfSBj
YXRjaCB7DQogICAgICAgICAgICBDb3B5LUl0ZW0gLUxpdGVyYWxQYXRoICR0bXAgLURlc3RpbmF0
aW9uICRwYXRoIC1Gb3JjZQ0KICAgICAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICR0
bXAgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlDQogICAgICAgIH0NCiAgICB9
DQogICAgcmV0dXJuICRjaGFuZ2VkDQp9DQoNCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tDQojIOWNleWunuS+i+mU
gQ0KIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
LS0tLS0tLS0tLS0tLS0tLS0NCiRjcmVhdGVkID0gJGZhbHNlDQokbXV0ZXggPSBOZXctT2JqZWN0
IFN5c3RlbS5UaHJlYWRpbmcuTXV0ZXgoJHRydWUsICRMT0NLX05BTUUsIFtyZWZdJGNyZWF0ZWQp
DQppZiAoLW5vdCAkY3JlYXRlZCkgeyBleGl0IDAgfQ0KDQokbGFzdE1vZGUgPSAkbnVsbA0KJGlk
bGVUaWNrcyA9IDANCnRyeSB7DQogICAgJHN0b3BGbGFnID0gSm9pbi1QYXRoIChTcGxpdC1QYXRo
IC1QYXJlbnQgJFBTQ29tbWFuZFBhdGgpICdhZGFwdGl2ZS13YXRjaC5zdG9wJw0KICAgIHdoaWxl
ICgkdHJ1ZSkgew0KICAgICAgICAjIOS8mOmbhemAgOWHuu+8mkNMQlQgLWFkYXB0aXZlIG9mZiDk
vJrlhpnov5nkuKrmoIflv5fmlofku7YNCiAgICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBh
dGggJHN0b3BGbGFnKSB7DQogICAgICAgICAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJHN0
b3BGbGFnIC1Gb3JjZSAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZQ0KICAgICAgICAgICAg
YnJlYWsNCiAgICAgICAgfQ0KDQogICAgICAgICRzcCA9IEdldC1TZXR0aW5nc1BhdGgNCiAgICAg
ICAgaWYgKC1ub3QgJHNwKSB7IFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgJEludGVydmFsTXM7
IGlmICgkT25jZSkgeyBicmVhayB9OyBjb250aW51ZSB9DQoNCiAgICAgICAgdHJ5IHsgJGpzb24g
PSBHZXQtRmlsZUpzb24gJHNwIH0gY2F0Y2ggeyAkanNvbiA9ICRudWxsIH0NCiAgICAgICAgaWYg
KCRudWxsIC1lcSAkanNvbikgew0KICAgICAgICAgICAgIyBzZXR0aW5ncy5qc29uIOato+WcqOii
q+e7iOerr+aUueWGmeaIluagvOW8j+W8guW4uO+8jOi3s+i/h+i/meS4gOi9rg0KICAgICAgICAg
ICAgaWYgKCRPbmNlKSB7IGJyZWFrIH0NCiAgICAgICAgICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNl
Y29uZHMgJEludGVydmFsTXMNCiAgICAgICAgICAgIGNvbnRpbnVlDQogICAgICAgIH0NCiAgICAg
ICAgJG9wYWNpdHkgPSBHZXQtT3BhY2l0eSAkanNvbg0KICAgICAgICAkZW5hYmxlZCA9ICgkb3Bh
Y2l0eSAtbHQgNzUpICAgIyDkuI3pgI/mmI7luqYgPCA3NSUg5omN5ZCv55So6Ieq6YCC5bqUDQoN
CiAgICAgICAgaWYgKCRlbmFibGVkKSB7DQogICAgICAgICAgICBpZiAoJEZvcmNlTHVtIC1nZSAw
KSB7ICRsdW0gPSAkRm9yY2VMdW0gfQ0KICAgICAgICAgICAgZWxzZSB7DQogICAgICAgICAgICAg
ICAgJHJlY3QgPSBHZXQtVGVybWluYWxSZWN0DQogICAgICAgICAgICAgICAgaWYgKCRyZWN0KSB7
ICRsdW0gPSBHZXQtQmFja2Ryb3BMdW1pbmFuY2UgJHJlY3QgfQ0KICAgICAgICAgICAgICAgIGVs
c2UgeyAkbHVtID0gLTE7ICRpZGxlVGlja3MrKyB9DQogICAgICAgICAgICB9DQoNCiAgICAgICAg
ICAgIGlmICgkUHJvYmUpIHsNCiAgICAgICAgICAgICAgICBXcml0ZS1PdXRwdXQgKCJiYWNrZHJv
cCBsdW1pbmFuY2UgPSAiICsgJGx1bSkNCiAgICAgICAgICAgICAgICBicmVhaw0KICAgICAgICAg
ICAgfQ0KDQogICAgICAgICAgICBpZiAoJGx1bSAtZ2UgMCkgew0KICAgICAgICAgICAgICAgICRp
ZGxlVGlja3MgPSAwDQogICAgICAgICAgICAgICAgJG1vZGUgPSBpZiAoJGx1bSAtZ2UgJFRocmVz
aG9sZCkgeyAnZGFyay10ZXh0JyB9IGVsc2UgeyAnbGlnaHQtdGV4dCcgfQ0KICAgICAgICAgICAg
ICAgIGlmICgkbW9kZSAtbmUgJGxhc3RNb2RlKSB7DQogICAgICAgICAgICAgICAgICAgICRmZyA9
IGlmICgkbW9kZSAtZXEgJ2RhcmstdGV4dCcpIHsgJEZHX0RBUksgfSBlbHNlIHsgJEZHX0xJR0hU
IH0NCiAgICAgICAgICAgICAgICAgICAgaWYgKFNldC1Gb3JlZ3JvdW5kICRzcCAkanNvbiAkZmcp
IHsNCiAgICAgICAgICAgICAgICAgICAgICAgIFdyaXRlLU91dHB1dCAoIlt7MH1dIOiDjOaZr+S6
ruW6piB7MX0gLT4gezJ9IHszfSIgLWYgKEdldC1EYXRlIC1Gb3JtYXQgJ0hIOm1tOnNzJyksICRs
dW0sICRtb2RlLCAkZmcpDQogICAgICAgICAgICAgICAgICAgIH0NCiAgICAgICAgICAgICAgICAg
ICAgJGxhc3RNb2RlID0gJG1vZGUNCiAgICAgICAgICAgICAgICB9DQogICAgICAgICAgICB9DQog
ICAgICAgIH0NCg0KICAgICAgICAjIOaJvuS4jeWIsOe7iOerr+eql+WPo+WkquS5heWwsemAgOWH
uu+8jOmBv+WFjeaui+eVmei/m+eoiw0KICAgICAgICBpZiAoJGlkbGVUaWNrcyAtZ3QgW2ludF0o
JE1heElkbGVTZWMgLyBbTWF0aF06Ok1heCgxLCAkSW50ZXJ2YWxNcyAvIDEwMDApKSkgeyBicmVh
ayB9DQoNCiAgICAgICAgaWYgKCRPbmNlKSB7IGJyZWFrIH0NCiAgICAgICAgU3RhcnQtU2xlZXAg
LU1pbGxpc2Vjb25kcyAkSW50ZXJ2YWxNcw0KICAgIH0NCn0NCmZpbmFsbHkgew0KICAgIHRyeSB7
ICRtdXRleC5SZWxlYXNlTXV0ZXgoKSB9IGNhdGNoIHsgfQ0KICAgICRtdXRleC5EaXNwb3NlKCkN
Cn0NCg==
'@

function Get-AdaptiveDir {
    if ($env:WT_ADAPTIVE_DIR) { return $env:WT_ADAPTIVE_DIR }
    return (Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify')
}

function Get-AdaptivePath { return (Join-Path (Get-AdaptiveDir) 'adaptive-watch.ps1') }

$AdaptiveHook = @'

# ---- 自适应前景色守护（由 CLBT -adaptive 安装；脚本不存在则什么都不做）----
try {
    $awPath = Join-Path $env:LOCALAPPDATA 'WindowsCommandLineBeautify\adaptive-watch.ps1'
    if (Test-Path -LiteralPath $awPath) {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$awPath`"") `
            -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    }
} catch { }
'@

function Install-Adaptive {
    $dir = Get-AdaptiveDir
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $awPath = Get-AdaptivePath

    $bytes = [Convert]::FromBase64String(($AdaptiveWatchB64 -replace '\s', ''))
    [System.IO.File]::WriteAllBytes($awPath, $bytes)
    Good ('自适应脚本已写入: ' + $awPath + '  (' + $bytes.Length + ' 字节)')

    $dirs = @()
    if ($env:WT_PROFILE_DIR) { $dirs += $env:WT_PROFILE_DIR }
    else {
        $dirs += (Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell')
        $ps7 = Join-Path $env:USERPROFILE 'Documents\PowerShell'
        if (Test-Path -LiteralPath $ps7) { $dirs += $ps7 }
    }
    foreach ($d in $dirs) {
        $prof = Join-Path $d 'Microsoft.PowerShell_profile.ps1'
        if (Test-Path -LiteralPath $prof) {
            $txt = [System.IO.File]::ReadAllText($prof)
            if ($txt -notlike '*adaptive-watch.ps1*') {
                [System.IO.File]::AppendAllText($prof, $AdaptiveHook, (New-Object System.Text.UTF8Encoding($false)))
                Good ('已在 profile 挂上启动钩子: ' + $prof)
            }
            else { Good 'profile 已有启动钩子，跳过' }
        }
    }

    # 上一轮如果留下了停止标志，新守护会立刻自杀；这里先清掉
    $staleFlag = Join-Path $dir 'adaptive-watch.stop'
    Remove-Item -LiteralPath $staleFlag -Force -ErrorAction SilentlyContinue

    try {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$awPath`"") `
            -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
        Good '自适应守护已启动（不透明度 < 75% 时按背景明暗切换字体深浅）'
    } catch { Warn ('启动守护失败: ' + $_.Exception.Message) }
}

function Remove-Adaptive {
    # 不杀进程：写一个停止标志，守护每个循环都会检查它然后自行退出
    $dir = Get-AdaptiveDir
    $stopFlag = Join-Path $dir 'adaptive-watch.stop'
    if (Test-Path -LiteralPath $dir) {
        [System.IO.File]::WriteAllText($stopFlag, 'stop', (New-Object System.Text.UTF8Encoding($false)))
        # 等一下让守护自己退出（最多 4 秒）
        $exited = $false
        for ($i = 0; $i -lt 30; $i++) {
            $alive = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
                       Where-Object { $_.CommandLine -and $_.CommandLine -like '*adaptive-watch.ps1*' -and $_.ProcessId -ne $PID })
            if ($alive.Count -eq 0) { $exited = $true; break }
            Start-Sleep -Milliseconds 200
        }
        if ($exited) {
            # 守护退出时会自己删掉标志文件；这里兜底清理一次
            Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue
            Good '自适应守护已退出'
        }
        else {
            # 没等到退出：强杀，然后把标志清掉（否则下次 -adaptive 新守护第一轮就自杀）
            try {
                Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
                    Where-Object { $_.CommandLine -and $_.CommandLine -like '*adaptive-watch.ps1*' -and $_.ProcessId -ne $PID } |
                    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                Good '自适应守护已强制结束'
            }
            catch { Warn ('强制结束守护失败: ' + $_.Exception.Message) }
            Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue
        }
    }

    $awPath = Get-AdaptivePath
    if (Test-Path -LiteralPath $awPath) {
        Remove-Item -LiteralPath $awPath -Force -ErrorAction SilentlyContinue
        Good '自适应脚本已删除（profile 钩子会因找不到脚本而失效）'
    }
    else { Write-Host '  [--]   自适应未被启用过' -ForegroundColor DarkGray }
}
# =====================================================================
# 读取「当前」风格（供只调透明度/字体时沿用，避免把 win 悄悄改成 linux）
# =====================================================================
function Get-CurrentStyle {
    $sp = $env:WT_SETTINGS_PATH
    if (-not $sp) {
        $cands = @(
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'),
            (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal Preview\settings.json')
        )
        $sp = $cands | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $sp -or -not (Test-Path -LiteralPath $sp)) { return '' }
    try {
        $raw = [System.IO.File]::ReadAllText($sp, [System.Text.UTF8Encoding]::new($false))
        $j = (Strip-JsonComments $raw) | ConvertFrom-Json
        $cs = $null
        if ($j.PSObject.Properties.Name -contains 'profiles' -and $null -ne $j.profiles -and
            $j.profiles.PSObject.Properties.Name -contains 'defaults' -and $null -ne $j.profiles.defaults) {
            $cs = $j.profiles.defaults.colorScheme
        }
        if ($cs -eq 'Linux (Tango)') { return 'linux' }
        if ($cs) { return 'win' }
        return ''
    } catch { return '' }
}

# =====================================================================
# 命令行帮助
# =====================================================================
function Show-CliHelp {
    Write-Host ''
    Write-Host '  || Windows 命令行 美化工具 ||' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  用法：' -ForegroundColor White
    Write-Host '    CLBT                          交互式菜单（首次使用推荐）' -ForegroundColor Gray
    Write-Host '    CLBT -linux                   仿 Linux：黑色亚克力 + bash 提示符' -ForegroundColor Gray
    Write-Host '    CLBT -win                     Windows 原生：默认配色、不透明、默认提示符' -ForegroundColor Gray
    Write-Host '    CLBT -transparent <0-100>     设置透明度（0=不透明，100=全透；两种风格都生效）' -ForegroundColor Gray
    Write-Host '    CLBT -opacity <0-100>         直接设置不透明度（100=完全不透明，同 Terminal 的 opacity）' -ForegroundColor Gray
    Write-Host '    CLBT -background "<图片路径>"  设置背景图片（png/jpg/jpeg/gif/bmp，可与透明度叠加）' -ForegroundColor Gray
    Write-Host '    CLBT -background off          移除背景图片' -ForegroundColor Gray
    Write-Host '    CLBT -bg-align <对齐>         背景图对齐: 居中 center / 顶部 top / 底部 bottom / 左侧 left / 右侧 right' -ForegroundColor Gray
    Write-Host '                                 另有 左上 topLeft / 右上 topRight / 左下 bottomLeft / 右下 bottomRight' -ForegroundColor DarkGray
    Write-Host '    CLBT -bg-stretch <拉伸>       背景图拉伸: 铺满并裁剪 uniformToFill / 拉伸填满 fill / 完整显示 uniform / 原始尺寸 none' -ForegroundColor Gray
    Write-Host '    CLBT -bg-opacity <0-1>        背景图浓淡（0-1，默认 0.55；越小越透）' -ForegroundColor Gray
    Write-Host '    CLBT -cell-height <0.8-2.0>   行高（如 1.2，越大行距越松）' -ForegroundColor Gray
    Write-Host '    CLBT -antialiasing <模式>     抗锯齿: 灰度柔和 grayscale / 清晰锐利 cleartype / 像素风 aliased' -ForegroundColor Gray
    Write-Host '    CLBT -adjust-colors <策略>    颜色修正: 总是修正 always / 仅索引色 indexed / 不修正 never' -ForegroundColor Gray
    Write-Host '    CLBT -encoding on|off         让 cmd 标签以 UTF-8 启动（消除 bat 中文乱码）' -ForegroundColor Gray
    Write-Host '    CLBT -font "<字体文件路径>"    安装并使用指定字体（.ttf/.otf/.ttc，或目录）' -ForegroundColor Gray
    Write-Host '    CLBT -face "<字体族名>"        直接用已安装的字族（如 0xProto Nerd Font Mono）' -ForegroundColor Gray
    Write-Host '    CLBT -font-weight <字重>      字重: 常规 normal / 粗体 bold' -ForegroundColor Gray
    Write-Host '    CLBT -acrylic on|off          亚克力磨砂: 开（默认，磨砂玻璃）/ 关（真透明，看得到桌面）' -ForegroundColor Gray
    Write-Host '    CLBT -install-fonts          只安装内置的 10 个字体，不改任何设置' -ForegroundColor Gray
    Write-Host '    CLBT -gui                    打开图形界面（等同于双击 CLBT-GUI.exe）' -ForegroundColor Gray
    Write-Host '    CLBT -diagnose               环境诊断：设置写到了哪、当前窗口是谁在渲染' -ForegroundColor Gray
    Write-Host '    CLBT -adaptive                开启自适应前景色（透明时按背景明暗切字体深浅）' -ForegroundColor Gray
    Write-Host '    CLBT -adaptive off            关闭自适应前景色' -ForegroundColor Gray
    Write-Host '    CLBT -uninstall               撤回对命令行的修改（外观/提示符/cmd 挂钩还原）' -ForegroundColor Gray
    Write-Host '    CLBT -help                    显示本帮助' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  提示：不给 -linux / -win 时沿用当前风格（只调透明度不会改变观感）' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  示例：' -ForegroundColor White
    Write-Host '    CLBT -linux                   # 默认不透明度 36%' -ForegroundColor DarkGray
    Write-Host '    CLBT -linux -transparent 50   # 更透一些' -ForegroundColor DarkGray
    Write-Host '    CLBT -win                     # 恢复 Windows 原生观感' -ForegroundColor DarkGray
    Write-Host '    CLBT -linux -font "D:\fonts\MyFont.ttf"' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  其他参数：' -ForegroundColor White
    Write-Host '    --undo-cmd                    移除 cmd 的仿 Linux 提示符' -ForegroundColor DarkGray
    Write-Host ''
}

# =====================================================================
# 入口分发
# =====================================================================
try {

if ($env:WT_MODE -eq 'help') {
    Show-CliHelp
    exit 0
}

if ($env:WT_MODE -eq 'encoding') {
    try {
        Set-EncodingMode ($env:WT_ENCODING -ne 'off')
        Write-Host ''
        if ($env:WT_ENCODING -eq 'off') { Write-Host '  已关闭 UTF-8 代码页（cmd 回到系统默认）' -ForegroundColor Green }
        else { Write-Host '  已开启：Terminal 里的 cmd 标签将以 UTF-8 运行，UTF-8 编码的 .bat 不再乱码' -ForegroundColor Green }
        Write-Host '  提示：GBK(ANSI) 编码的 .bat 反而会乱码，可用记事本另存为 UTF-8。' -ForegroundColor DarkGray
        Write-Host ''
        exit 0
    }
    catch {
        Write-Host ('设置失败: ' + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

if ($env:WT_MODE -eq 'badarg') {
    Write-Host ('未知参数: ' + $env:WT_BADARG) -ForegroundColor Red
    Write-Host '用 CLBT -help 查看全部用法' -ForegroundColor Yellow
    exit 2
}

if ($env:WT_MODE -eq 'adaptive') {
    try {
        if ($env:WT_ADAPTIVE -eq 'off') {
            Remove-Adaptive
            Write-Host ''
            Write-Host '  已关闭自适应前景色。' -ForegroundColor Green
        }
        else {
            Install-Adaptive
            Write-Host ''
            Write-Host '  自适应前景色已启用：不透明度 < 75% 时，亮背景用深色字、暗背景用浅色字。' -ForegroundColor Green
            if ((Get-CurrentStyle) -eq 'win') {
                Write-Host '  注意：当前是 Windows 原生风格，自适应只作用于仿 Linux 配色，暂时看不到效果。' -ForegroundColor Yellow
            }
            Write-Host '  关闭：CLBT -adaptive off' -ForegroundColor DarkGray
        }
        Write-Host ''
        exit 0
    }
    catch {
        Write-Host ('操作失败: ' + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

if ($env:WT_MODE -eq 'uninstall') {
    try {
        Invoke-Uninstall
        Write-Host ''
        Write-Host '  已撤回对命令行的修改。请新开终端标签页确认。' -ForegroundColor Green
        Write-Host ''
        exit 0
    }
    catch {
        Write-Host ("撤回失败: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}


if ($env:WT_MODE -eq 'diag') {
    Write-Host ''
    Write-Host '  || CLBT 环境诊断 ||' -ForegroundColor Cyan
    Write-Host ''

    # ---- 1) settings.json 候选
    $la = $env:LOCALAPPDATA
    $cands = @(
        (Join-Path $la 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $la 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $la 'Microsoft\Windows Terminal\settings.json'),
        (Join-Path $la 'Microsoft\Windows Terminal Preview\settings.json')
    )
    Write-Host '  [设置文件]' -ForegroundColor White
    $active = $null
    foreach ($c in $cands) {
        if (Test-Path -LiteralPath $c) {
            $op = '?'; $ac = '?'; $bg = '?'
            try {
                $raw = [System.IO.File]::ReadAllText($c, [System.Text.UTF8Encoding]::new($false))
                $j = (Strip-JsonComments $raw) | ConvertFrom-Json
                $d = $j.profiles.defaults
                $op = $d.opacity
                $ac = $d.useAcrylic
                $bg = if ($d.backgroundImage) { Split-Path -Leaf $d.backgroundImage } else { '（无）' }
            } catch { }
            $t = (Get-Item -LiteralPath $c).LastWriteTime.ToString('MM-dd HH:mm:ss')
            Write-Host ('    ' + $c) -ForegroundColor Gray
            Write-Host ('      opacity=' + $op + '  useAcrylic=' + $ac + '  背景图=' + $bg + '  改于 ' + $t) -ForegroundColor Gray
            if (-not $active) { $active = $c }
        }
        else {
            Write-Host ('    ' + $c + '   [不存在]') -ForegroundColor DarkGray
        }
    }
    Write-Host ''

    # ---- 2) 当前进程链（谁在渲染这个窗口）
    Write-Host '  [当前窗口的进程链]' -ForegroundColor White
    $chain = @()
    $pidCur = $PID
    for ($i = 0; $i -lt 8; $i++) {
        $pr = Get-Process -Id $pidCur -ErrorAction SilentlyContinue
        if (-not $pr) { break }
        $chain += $pr.ProcessName
        Write-Host ('    ' + $pr.ProcessName + '  (pid ' + $pr.Id + ')') -ForegroundColor Gray
        $ci = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $pidCur) -ErrorAction SilentlyContinue
        if (-not $ci -or -not $ci.ParentProcessId) { break }
        $pidCur = [int]$ci.ParentProcessId
    }
    $hostName = if ($chain.Count -gt 1) { $chain[$chain.Count - 1] } else { $chain[0] }
    $inWT = ($chain | Where-Object { $_ -like 'WindowsTerminal*' -or $_ -eq 'wt' })
    $inCode = ($chain | Where-Object { $_ -like 'Code*' })
    Write-Host ''

    # ---- 3) 已安装的 Windows Terminal
    Write-Host '  [Windows Terminal]' -ForegroundColor White
    $pkgs = @(Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue)
    $pkgs += @(Get-AppxPackage -Name 'Microsoft.WindowsTerminalPreview' -ErrorAction SilentlyContinue)
    if ($pkgs.Count -gt 0) {
        foreach ($p in $pkgs) { Write-Host ('    ' + $p.Name + '  ' + $p.Version) -ForegroundColor Gray }
    }
    else {
        Write-Host '    没有装 Store 版 Windows Terminal' -ForegroundColor Yellow
    }
    Write-Host ''

    # ---- 4) 系统透明效果开关
    Write-Host '  [系统透明效果]' -ForegroundColor White
    $tg = '?'
    try {
        $tg = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction Stop).EnableTransparency
    } catch { }
    Write-Host ('    EnableTransparency = ' + $tg + $(if ($tg -eq 0) { '   ← 关掉了！系统把透明效果整体禁用了' } else { '' })) -ForegroundColor Gray
    Write-Host ''

    # ---- 5) 结论
    Write-Host '  [结论]' -ForegroundColor White
    if ($inWT) {
        Write-Host '    当前窗口就是 Windows Terminal，用它下面的设置文件 ✓' -ForegroundColor Green
    }
    elseif ($inCode) {
        Write-Host '    当前窗口是 VS Code 的集成终端！' -ForegroundColor Yellow
        Write-Host '    VS Code 终端不读 Windows Terminal 的 settings.json，所以改透明度、配色、字体都不会生效。' -ForegroundColor Yellow
        Write-Host '    请按 Win 键搜索 “终端 / Terminal” 打开 Windows Terminal 再试。' -ForegroundColor Yellow
    }
    else {
        Write-Host ('    当前窗口的宿主是 ' + $hostName + '，看起来不是 Windows Terminal。') -ForegroundColor Yellow
        Write-Host '    只有 Windows Terminal（WindowsTerminal.exe / wt.exe）会读取这些设置；' -ForegroundColor Yellow
        Write-Host '    双击 cmd 出来的传统控制台窗口不受影响。' -ForegroundColor Yellow
    }
    if ($tg -eq 0) {
        Write-Host '    另外：系统的“透明效果”是关的 —— 设置 → 个性化 → 颜色 → 透明效果 打开。' -ForegroundColor Yellow
    }
    Write-Host ''
    exit 0
}

if ($env:WT_MODE -eq 'installfonts') {
    # 只安装内嵌的 10 个字体，不改任何外观设置（GUI / 脚本预置字体用）
    try {
        $stage = Join-Path $env:TEMP ('wt_fonts_' + [guid]::NewGuid().ToString('N'))
        $files = Expand-EmbeddedFonts $stage
        if ($files.Count -eq 0) {
            Write-Host '  内嵌字体解码失败（文件可能损坏）' -ForegroundColor Red
            exit 4
        }
        $fams = New-Object System.Collections.ArrayList
        foreach ($f in $files) {
            $fam = Get-FamilyOf $f.FullName $f.BaseName
            if (-not $fams.Contains($fam)) { [void]$fams.Add($fam) }
        }
        Install-FontFile $stage | Out-Null
        Write-Host ('  内置字体已就绪：' + $files.Count + ' 个文件 / ' + $fams.Count + ' 个字族') -ForegroundColor Green
        foreach ($x in $fams) { Write-Host ('    ' + $x) -ForegroundColor Gray }
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        exit 0
    }
    catch {
        Write-Host ('字体安装失败: ' + $_.Exception.Message) -ForegroundColor Red
        exit 3
    }
}

if ($env:WT_MODE -eq 'cli') {
    $style = ''
    if ($env:WT_STYLE) { $style = $env:WT_STYLE.Trim().ToLower() }
    $styleNote = ''
    if (-not $style) {
        # 只给了 -transparent / -font 时，不能悄悄改风格
        $style = Get-CurrentStyle
        if ($style) { $styleNote = '（沿用当前风格）' }
        else { $style = 'linux'; $styleNote = '（默认）' }
    }
    if ($style -notin @('linux', 'win')) {
        Write-Host ("未知风格: " + $style + "（可选 linux / win，用 -help 查看用法）") -ForegroundColor Red
        exit 2
    }

    $op = if ($style -eq 'win') { 100 } else { 36 }
    $opText = ''

    # -opacity N：N 就是「不透明度」（100 = 完全不透明，与 Terminal 的 opacity 同义）
    if ($env:WT_OPACITY) {
        $parsed = 0
        if (-not [int]::TryParse($env:WT_OPACITY.Trim(), [ref]$parsed) -or $parsed -lt 0 -or $parsed -gt 100) {
            Write-Host ("不透明度需要 0-100 的整数，收到: " + $env:WT_OPACITY) -ForegroundColor Red
            exit 2
        }
        $op = $parsed
        $opText = ('不透明度 ' + $op + '%')
    }
    # -transparent N：N 是「透明度」，不透明度 = 100 - N
    elseif ($env:WT_TRANSPARENT) {
        $parsed = 0
        if (-not [int]::TryParse($env:WT_TRANSPARENT.Trim(), [ref]$parsed) -or $parsed -lt 0 -or $parsed -gt 100) {
            Write-Host ("透明度需要 0-100 的整数，收到: " + $env:WT_TRANSPARENT) -ForegroundColor Red
            exit 2
        }
        $op = 100 - $parsed
        $opText = ('透明度 ' + $parsed + '%（不透明度 ' + $op + '%）')
    }

    if (-not $opText) { $opText = ('不透明度 ' + $op + '%') }

    # ---- 先把该报错的都报完，再动 settings.json（失败不该留下备份/半成品）----
    if ($env:WT_BGOPACITY) {
        $tmpOp = 0.0
        if (-not [double]::TryParse($env:WT_BGOPACITY, [ref]$tmpOp) -or $tmpOp -lt 0.0 -or $tmpOp -gt 1.0) {
            Write-Host ("背景图浓淡需要 0-1 之间的小数（如 0.55），收到: " + $env:WT_BGOPACITY) -ForegroundColor Red
            exit 2
        }
    }
    if ($env:WT_BGALIGN) {
        $okAlign = @('center', 'top', 'bottom', 'left', 'right', 'topLeft', 'topRight', 'bottomLeft', 'bottomRight')
        if ($env:WT_BGALIGN -notin $okAlign) {
            Write-Host ("背景图对齐只能是 " + ($okAlign -join ' / ') + "，收到: " + $env:WT_BGALIGN) -ForegroundColor Red
            exit 2
        }
    }
    if ($env:WT_BGSTRETCH) {
        $okStretch = @('fill', 'none', 'uniform', 'uniformToFill')
        if ($env:WT_BGSTRETCH -notin $okStretch) {
            Write-Host ("背景图拉伸只能是 " + ($okStretch -join ' / ') + "，收到: " + $env:WT_BGSTRETCH) -ForegroundColor Red
            exit 2
        }
    }
    if ($env:WT_CELLHEIGHT) {
        $tmpCh = 0.0
        if (-not [double]::TryParse($env:WT_CELLHEIGHT, [ref]$tmpCh) -or $tmpCh -lt 0.8 -or $tmpCh -gt 2.0) {
            Write-Host ("行高需要 0.8-2.0 之间的数字（如 1.2），收到: " + $env:WT_CELLHEIGHT) -ForegroundColor Red
            exit 2
        }
    }
    if ($env:WT_AA -and $env:WT_AA -notin @('grayscale', 'cleartype', 'aliased')) {
        Write-Host ("抗锯齿只能是 grayscale / cleartype / aliased，收到: " + $env:WT_AA) -ForegroundColor Red
        exit 2
    }
    if ($env:WT_ADJUST -and $env:WT_ADJUST -notin @('always', 'indexed', 'never')) {
        Write-Host ("颜色修正只能是 always / indexed / never，收到: " + $env:WT_ADJUST) -ForegroundColor Red
        exit 2
    }
    if ($env:WT_ACRYLIC) {
        $okAc = @('on', 'off', 'true', 'false', '1', '0', '开', '关', '开启', '关闭')
        if ($env:WT_ACRYLIC.Trim().ToLower() -notin $okAc) {
            Write-Host ("亚克力只能是 on / off（开 / 关），收到: " + $env:WT_ACRYLIC) -ForegroundColor Red
            exit 2
        }
    }

    $cliFace = ''
    $faceMissing = $false
    if ($env:WT_FONTFILE) {
        try {
            $cliFace = Install-FontFile $env:WT_FONTFILE
            Write-Host ("  使用指定字体: " + $cliFace) -ForegroundColor Cyan
        }
        catch {
            Write-Host ("字体处理失败: " + $_.Exception.Message) -ForegroundColor Red
            exit 3
        }
    }
    elseif ($env:WT_FACE) {
        $cliFace = [string]$env:WT_FACE
        # 这里只提示，不丢弃：内置字体是在 Invoke-Beautify 第 3 步才安装的，
        # 新机器首次指定内置字族时此刻还查不到，丢弃会误伤
        $faceMissing = -not (Test-FontFamilyInstalled $cliFace)
        Write-Host ("  使用字族: " + $cliFace) -ForegroundColor Cyan
    }
    elseif ($style -eq 'linux') { $cliFace = '0xProto Mono Italic' }

    try {
        Invoke-Beautify -Face $cliFace -Style $style -Opacity $op -Background ([string]$env:WT_BACKGROUND) `
        -AdjustColors ([string]$env:WT_ADJUST) -CellHeight ([string]$env:WT_CELLHEIGHT) `
        -Antialiasing ([string]$env:WT_AA) -BgAlign ([string]$env:WT_BGALIGN) -BgStretch ([string]$env:WT_BGSTRETCH) `
        -BgOpacity ([string]$env:WT_BGOPACITY) -FontWeight ([string]$env:WT_FONTWEIGHT) `
        -Acrylic ([string]$env:WT_ACRYLIC)
        Write-Host ''
        if ($style -eq 'win') {
            Write-Host ('  完成：Windows 原生风格' + $styleNote + '（' + $opText + '、默认配色、默认提示符）') -ForegroundColor Green
        }
        else {
            Write-Host ('  完成：仿 Linux 风格' + $styleNote + '，' + $opText) -ForegroundColor Green
        }
        if ($faceMissing) {
            if (Test-FontFamilyInstalled $cliFace) {
                Good ("字族 " + $cliFace + " 本次运行已装好，Terminal 可直接使用")
            }
            else {
                Write-Host ("  [!!] 系统里仍找不到字族: " + $cliFace + "，Terminal 会回退到默认字体") -ForegroundColor Yellow
                Write-Host '       检查拼写，或先跑 CLBT -install-fonts 装内置字体；CLBT -help 里有可用字族名' -ForegroundColor DarkGray
            }
        }
        Write-Host '  新开终端标签页生效；已经是新标签页则重启终端。' -ForegroundColor DarkGray
        Write-Host ''
        exit 0
    }
    catch {
        Write-Host ("失败: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

if ($env:WT_MODE -eq 'undo') {
    try {
        Remove-CmdPrompt
        Write-Host '  已移除 cmd 的仿 Linux 提示符（AutoRun 已还原，新开的 cmd 恢复正常）' -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Host ("移除失败: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

if ($env:WT_MODE -eq 'apply') {
    # ---- 静默应用模式（由父进程以子进程方式调用）----
    # 注意：父进程用 Start-Process -PassThru 拿到的 ExitCode 恒为 null，
    # 所以成功/失败通过状态文件回传，不依赖退出码。
    try {
        $apStyle = if ($env:WT_STYLE) { ([string]$env:WT_STYLE).Trim().ToLower() } else { 'linux' }
        $apOpacity = -1
        if ($env:WT_TRANSPARENT -and $env:WT_TRANSPARENT -match '^\d+$') {
            $apT = [int]$env:WT_TRANSPARENT
            if ($apT -ge 0 -and $apT -le 100) { $apOpacity = 100 - $apT }
        }
        Invoke-Beautify -Face ([string]$env:WT_FACE) -Style $apStyle -Opacity $apOpacity -Background ([string]$env:WT_BACKGROUND) `
            -AdjustColors ([string]$env:WT_ADJUST) -CellHeight ([string]$env:WT_CELLHEIGHT) `
            -Antialiasing ([string]$env:WT_AA) -BgAlign ([string]$env:WT_BGALIGN) -BgStretch ([string]$env:WT_BGSTRETCH) `
            -BgOpacity ([string]$env:WT_BGOPACITY) -FontWeight ([string]$env:WT_FONTWEIGHT) `
            -Acrylic ([string]$env:WT_ACRYLIC)
        if ($env:WT_STATUS_FILE) {
            [System.IO.File]::WriteAllText($env:WT_STATUS_FILE, 'OK', (New-Object System.Text.UTF8Encoding($false)))
        }
        exit 0
    }
    catch {
        if ($env:WT_STATUS_FILE) {
            [System.IO.File]::WriteAllText($env:WT_STATUS_FILE, ("FAIL: " + $_.Exception.Message), (New-Object System.Text.UTF8Encoding($false)))
        }
        Write-Host ("应用失败: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

# ---- 交互模式 ----
try { Clear-Host } catch { }   # 输出被重定向时 Clear-Host 会抛错
Write-Host ''
Write-Host '  || Windows 命令行 美化工具 ||' -ForegroundColor Cyan
Write-Host ''

# ---- 主菜单：命令行的每个能力这里都能到 ----
Write-Host '请选择操作 (填序号) :' -ForegroundColor White
Write-Host '  1) 应用美化   选择风格 / 透明度 / 字体，并可选 cmd 提示符与自适应前景色' -ForegroundColor Green
Write-Host '  2) 撤回修改   还原外观、提示符、cmd 挂钩、自适应（等价于 -uninstall）' -ForegroundColor Gray
Write-Host '  3) 查看帮助   列出全部命令行用法（等价于 -help）' -ForegroundColor Gray
Write-Host ''

$opPick = $null
for ($otry = 0; $otry -lt 3; $otry++) {
    Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
    $inpO = Read-Answer
    if ($null -eq $inpO) { $inpO = '' }
    $inpO = $inpO.Trim()
    if ($inpO -eq '') { $opPick = 1; break }
    $numO = 0
    if ([int]::TryParse($inpO, [ref]$numO) -and $numO -ge 1 -and $numO -le 3) { $opPick = $numO; break }
    Write-Host '  请输入 1 / 2 / 3（直接回车 = 1 应用美化）' -ForegroundColor Yellow
}
if (-not $opPick) { $opPick = 1 }
Write-Host ''

if ($opPick -eq 2) {
    try {
        Invoke-Uninstall
        Write-Host ''
        Write-Host '  已撤回对命令行的修改。请新开终端标签页确认。' -ForegroundColor Green
        Write-Host ''
    }
    catch { Write-Host ('撤回失败: ' + $_.Exception.Message) -ForegroundColor Red }
    exit 0
}

if ($opPick -eq 3) {
    Show-CliHelp
    exit 0
}

# ---- 第一步：选择风格 ----
$styleList = @('linux', 'win')
Write-Host '请选择风格 (填序号) :' -ForegroundColor White
Write-Host '  1) 仿 Linux      黑色亚克力 + Tango 配色 + bash 提示符' -ForegroundColor Green
Write-Host '  2) Windows 原生  默认配色 + 不透明 + Windows 默认提示符' -ForegroundColor Gray
Write-Host ''

$stylePick = $null
for ($stry = 0; $stry -lt 3; $stry++) {
    Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
    $inpS = Read-Answer
    if ($null -eq $inpS) { $inpS = '' }
    $inpS = $inpS.Trim()
    if ($inpS -eq '') { $stylePick = 1; break }
    $numS = 0
    if ([int]::TryParse($inpS, [ref]$numS) -and $numS -ge 1 -and $numS -le 2) { $stylePick = $numS; break }
    Write-Host '  序号无效，请重新输入 1 或 2（直接回车 = 1 仿 Linux）' -ForegroundColor Yellow
}
if (-not $stylePick) {
    Write-Host '  输入次数过多，使用仿 Linux 风格' -ForegroundColor Yellow
    $stylePick = 1
}
$chosenStyle = $styleList[$stylePick - 1]
Write-Host ''
if ($chosenStyle -eq 'win') {
    Write-Host '  已选择: Windows 原生风格' -ForegroundColor Cyan
}
else {
    Write-Host '  已选择: 仿 Linux 风格' -ForegroundColor Cyan
}
Write-Host ''

# ---- 第二步：设置透明度 ----
# 默认值按风格给：仿 Linux 用不透明度 36%（= 透明 64%），Windows 原生保持完全不透明
$defTransp = if ($chosenStyle -eq 'win') { 0 } else { 64 }
Write-Host '请设置透明度 (填 0-100，0 = 完全不透明，100 = 全透) :' -ForegroundColor White
Write-Host ("  直接回车 = " + $defTransp + "%" + $(if ($chosenStyle -eq 'win') { '（Windows 原生默认不透明）' } else { '（仿 Linux 默认）' })) -ForegroundColor DarkGray
Write-Host ''

$chosenTransp = $null
for ($ttry = 0; $ttry -lt 3; $ttry++) {
    Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
    $inpT = Read-Answer
    if ($null -eq $inpT) { $inpT = '' }
    $inpT = $inpT.Trim()
    if ($inpT -eq '') { $chosenTransp = $defTransp; break }
    $numT = 0
    if ([int]::TryParse($inpT, [ref]$numT) -and $numT -ge 0 -and $numT -le 100) { $chosenTransp = $numT; break }
    Write-Host '  请输入 0-100 的整数（直接回车 = 默认）' -ForegroundColor Yellow
}
if ($null -eq $chosenTransp) {
    Write-Host '  输入次数过多，使用默认值' -ForegroundColor Yellow
    $chosenTransp = $defTransp
}
$chosenOpacity = 100 - $chosenTransp
Write-Host ''
Write-Host ("  已选择: 透明度 " + $chosenTransp + "%（不透明度 " + $chosenOpacity + "%）") -ForegroundColor Cyan
Write-Host ''

# ---- 应用内容清单（随所选风格变化）----
$pvUser = $env:USERNAME
$pvHost = $env:COMPUTERNAME.ToLower()
Write-Host '将应用到：' -ForegroundColor DarkGray
if ($chosenStyle -eq 'linux') {
    Write-Host '  · 外观    ' -NoNewline -ForegroundColor DarkGray
    Write-Host ("黑色亚克力 不透明度 " + $chosenOpacity + "%   Tango 配色   方块光标") -ForegroundColor Gray
    Write-Host '  · 提示符  ' -NoNewline -ForegroundColor DarkGray
    Write-Host '仿 Linux  ' -NoNewline -ForegroundColor Cyan
    Write-Host "$pvUser@$pvHost" -NoNewline -ForegroundColor Green
    Write-Host ':' -NoNewline -ForegroundColor Gray
    Write-Host '~' -NoNewline -ForegroundColor Blue
    Write-Host '$ ' -NoNewline -ForegroundColor Gray
    Write-Host '(bash 风格；家目录显示为 ~ ，管理员显示 #)' -ForegroundColor DarkGray
}
else {
    Write-Host '  · 外观    ' -NoNewline -ForegroundColor DarkGray
    Write-Host ("Campbell 配色   不透明度 " + $chosenOpacity + "%   默认光标") -ForegroundColor Gray
    Write-Host '  · 提示符  ' -NoNewline -ForegroundColor DarkGray
    Write-Host 'Windows 默认  ' -NoNewline -ForegroundColor Cyan
    Write-Host 'PS C:\...>' -ForegroundColor Gray
    Write-Host '  · 说明    ' -NoNewline -ForegroundColor DarkGray
    Write-Host '会删除本工具生成的 profile，恢复系统默认提示符' -ForegroundColor Gray
}
Write-Host '  · cmd      ' -NoNewline -ForegroundColor DarkGray
Write-Host '可选（下面会询问）' -ForegroundColor Gray
Write-Host ''

# 用内嵌字体生成字体清单（家族去重，标注可用样式）
# 解码 10 个字体需要 2-3 秒，先给一行提示，避免看起来像卡住
Write-Host '  正在读取内置字体 · · ·' -NoNewline -ForegroundColor DarkCyan
$catalogStage = Join-Path $env:TEMP ('wt_cat_' + [guid]::NewGuid().ToString('N'))
$catalog = New-Object System.Collections.ArrayList
try {
    $catFiles = Expand-EmbeddedFonts $catalogStage
    $map = [ordered]@{}
    foreach ($f in $catFiles) {
        $fam = Get-FamilyOf $f.FullName $f.BaseName
        $style = Get-FontStyleOf $f.BaseName
        if (-not $map.Contains($fam)) { $map[$fam] = New-Object System.Collections.ArrayList }
        if (-not $map[$fam].Contains($style)) { [void]$map[$fam].Add($style) }
    }
    foreach ($k in $map.Keys) {
        [void]$catalog.Add([pscustomobject]@{ Family = $k; Styles = (@($map[$k]) -join ' / ') })
    }
} catch { }

if ($catalog.Count -eq 0) {
    [void]$catalog.Add([pscustomobject]@{ Family = '0xProto Mono Italic'; Styles = 'Regular' })
}
# 清掉"正在读取"那一行
Write-Host ("`r" + (' ' * 40) + "`r") -NoNewline

# win 风格默认用系统字体，因此在清单最前面加一项「不指定」
$noFontIdx = 0
if ($chosenStyle -eq 'win') {
    $catalog.Insert(0, [pscustomobject]@{ Family = '(不指定：使用系统默认字体)'; Styles = '-' })
    $noFontIdx = 1
}

$defaultIdx = $noFontIdx
if ($noFontIdx -eq 0) {
    for ($i = 0; $i -lt $catalog.Count; $i++) {
        if ($catalog[$i].Family -eq '0xProto Mono Italic') { $defaultIdx = $i + 1; break }
    }
}

Write-Host '请输入您要的字体 (填序号) :' -ForegroundColor White
for ($i = 0; $i -lt $catalog.Count; $i++) {
    $n = $i + 1
    $tail = ''
    if ($n -eq $defaultIdx) {
        if ($noFontIdx -gt 0 -and $n -eq $noFontIdx) { $tail = '   <- 推荐（Windows 原生，用系统字体）' }
        else { $tail = '   <- 推荐（斜体终端）' }
    }
    $styleCn = $catalog[$i].Styles -replace 'Bold Italic', '粗斜体' -replace 'Bold', '粗体' `
        -replace 'Italic', '斜体' -replace 'Regular', '常规'
    $shortName = @{ '0xProto Mono Italic' = '斜体'; '0xProto Nerd Font Mono' = '等宽'
                    '0xProto Nerd Font' = '标准'; '0xProto Nerd Font Propo' = '比例' }
    $showName = if ($shortName.ContainsKey($catalog[$i].Family)) { $shortName[$catalog[$i].Family] } else { $catalog[$i].Family }
    $line = '  {0}) {1,-8} {2}{3}' -f $n, $showName, $styleCn, $tail
    if ($n -eq $defaultIdx) { Write-Host $line -ForegroundColor Green }
    else { Write-Host $line -ForegroundColor Gray }
}
# 与命令行 -font "<路径>" 对应：允许直接指定字体文件
$customIdx = $catalog.Count + 1
Write-Host ('  {0}) 自定义字体文件…      （输入 .ttf/.otf/.ttc 路径，或包含字体的目录）' -f $customIdx) -ForegroundColor Gray
Write-Host ''

$choice = $null
for ($try = 0; $try -lt 3; $try++) {
    Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
    $inp = Read-Answer
    if ($null -eq $inp) { $inp = '' }
    $inp = $inp.Trim()
    if ($inp -eq '') { $choice = $defaultIdx; break }
    $num = 0
    if ([int]::TryParse($inp, [ref]$num) -and $num -ge 1 -and $num -le $customIdx) { $choice = $num; break }
    Write-Host '  序号无效，请重新输入（直接回车 = 默认）' -ForegroundColor Yellow
}
if (-not $choice) {
    Write-Host '  输入次数过多，使用默认字体' -ForegroundColor Yellow
    $choice = $defaultIdx
}

$face = ''
$faceDesc = ''
if ($choice -eq $customIdx) {
    for ($cp = 0; $cp -lt 3; $cp++) {
        Write-Host '  请输入字体文件路径（原样粘贴，可直接回车取消）: ' -NoNewline -ForegroundColor DarkCyan
        $fp = Read-Answer
        if ($null -eq $fp) { $fp = '' }
        $fp = $fp.Trim().Trim('"').Trim()
        if (-not $fp) { break }
        try {
            $face = Install-FontFile $fp
            $faceDesc = '自定义文件'
            break
        }
        catch { Write-Host ('  失败: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
}
else {
    $face = $catalog[$choice - 1].Family
    $faceDesc = $catalog[$choice - 1].Styles
    if ($noFontIdx -gt 0 -and $choice -eq $noFontIdx) { $face = '' }
}
Write-Host ''
if ($face) {
    $faceDescCn = $faceDesc -replace 'Bold Italic', '粗斜体' -replace 'Bold', '粗体' `
        -replace 'Italic', '斜体' -replace 'Regular', '常规'
    $faceShort = @{ '0xProto Mono Italic' = '斜体'; '0xProto Nerd Font Mono' = '等宽'
                    '0xProto Nerd Font' = '标准'; '0xProto Nerd Font Propo' = '比例' }
    $faceShow = if ($faceShort.ContainsKey($face)) { $faceShort[$face] + '（' + $face + '）' } else { $face }
    Write-Host ("  已选择字体: {0}  ({1})" -f $faceShow, $faceDescCn) -ForegroundColor Cyan
}
else {
    Write-Host '  已选择字体: 系统默认' -ForegroundColor Cyan
}
Write-Host ''

# ---- 第二个问题：cmd（命令提示符）是否也仿 Linux ----
Write-Host '是否让 cmd（命令提示符）也使用仿 Linux 提示符？' -ForegroundColor White
Write-Host '  [y] 是 —— 写入 HKCU 的 AutoRun 项，对所有 cmd 生效（可用 --undo-cmd 撤销）' -ForegroundColor Gray
Write-Host '  [N] 否 —— 只改 PowerShell（默认，直接回车）' -ForegroundColor Gray
Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
$ansCmd = Read-Answer
if ($null -eq $ansCmd) { $ansCmd = '' }
$ansCmd = $ansCmd.Trim().ToLower()
$cmdOn = ($ansCmd -eq 'y' -or $ansCmd -eq 'yes' -or $ansCmd -eq '是')
$env:WT_CMDPROMPT = if ($cmdOn) { '1' } else { '0' }
Write-Host ''
Write-Host ('  cmd 提示符: ' + $(if ($cmdOn) { '一并设为仿 Linux（AutoRun）' } else { '保持原样' })) -ForegroundColor Cyan
Write-Host ''

# ---- 背景图片（对应 -background "<图片路径>"）----
Write-Host '是否设置背景图片（png/jpg/jpeg/gif/bmp，可与透明度叠加）？' -ForegroundColor White
Write-Host '  直接回车跳过；输入 off 移除已有背景图；或粘贴图片完整路径' -ForegroundColor Gray
Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
$ansBg = Read-Answer
if ($null -eq $ansBg) { $ansBg = '' }
$ansBg = $ansBg.Trim().Trim('"').Trim()
$env:WT_BACKGROUND = $ansBg
Write-Host ''
if (-not $ansBg) { Write-Host '  背景图片: 保持原样' -ForegroundColor DarkGray }
elseif ($ansBg -eq 'off' -or $ansBg -eq 'none') { Write-Host '  背景图片: 将移除' -ForegroundColor Cyan }
else { Write-Host ('  背景图片: ' + $ansBg) -ForegroundColor Cyan }
Write-Host ''

# ---- 高级外观微调（对应 -adjust-colors / -cell-height / -antialiasing / -bg-align / -bg-stretch）----
Write-Host '是否微调高级外观（行高 / 抗锯齿 / 颜色修正 / 背景对齐）？(y/N，回车跳过)' -ForegroundColor White
Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
$ansAdv = Read-Answer
if ($null -eq $ansAdv) { $ansAdv = '' }
if ($ansAdv.Trim().ToLower() -in @('y', 'yes', '是')) {
    Write-Host ''
    Write-Host '  行高 (0.8-2.0，如 1.2；直接回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    $v = $v.Trim(); if ($v) { $env:WT_CELLHEIGHT = $v }

    Write-Host '  抗锯齿 1) 灰度柔和  2) 清晰锐利  3) 像素风   (回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    switch ($v.Trim()) {
        '1' { $env:WT_AA = 'grayscale' } '2' { $env:WT_AA = 'cleartype' } '3' { $env:WT_AA = 'aliased' }
        '灰度柔和' { $env:WT_AA = 'grayscale' } '清晰锐利' { $env:WT_AA = 'cleartype' } '像素风' { $env:WT_AA = 'aliased' }
    }

    Write-Host '  亚克力磨砂 1) 开（磨砂玻璃，看不清桌面） 2) 关（真透明，看得到桌面）  (回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    switch ($v.Trim()) {
        '1' { $env:WT_ACRYLIC = 'on' } '2' { $env:WT_ACRYLIC = 'off' }
        '开' { $env:WT_ACRYLIC = 'on' } '关' { $env:WT_ACRYLIC = 'off' }
    }

    Write-Host '  字重 1) 常规 2) 粗体   (回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    switch ($v.Trim()) {
        '1' { $env:WT_FONTWEIGHT = 'normal' } '2' { $env:WT_FONTWEIGHT = 'bold' }
        '常规' { $env:WT_FONTWEIGHT = 'normal' } '粗体' { $env:WT_FONTWEIGHT = 'bold' }
    }

    Write-Host '  自动修正不可辨认颜色（让看不清的颜色自动变亮/变深）？(y/N，回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    if ($v.Trim().ToLower() -in @('y', 'yes', '是')) { $env:WT_ADJUST = 'always' }
    elseif ($v.Trim().ToLower() -in @('n', 'no', '否')) { $env:WT_ADJUST = 'never' }

    Write-Host '  背景图对齐 1) 居中 2) 顶部 3) 底部 4) 左侧 5) 右侧 6) 左上 7) 右上 8) 左下 9) 右下  (回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    switch ($v.Trim()) {
        '1' { $env:WT_BGALIGN = 'center' } '2' { $env:WT_BGALIGN = 'top' } '3' { $env:WT_BGALIGN = 'bottom' }
        '4' { $env:WT_BGALIGN = 'left' } '5' { $env:WT_BGALIGN = 'right' } '6' { $env:WT_BGALIGN = 'topLeft' }
        '7' { $env:WT_BGALIGN = 'topRight' } '8' { $env:WT_BGALIGN = 'bottomLeft' } '9' { $env:WT_BGALIGN = 'bottomRight' }
        '居中' { $env:WT_BGALIGN = 'center' } '顶部' { $env:WT_BGALIGN = 'top' } '底部' { $env:WT_BGALIGN = 'bottom' }
        '左侧' { $env:WT_BGALIGN = 'left' } '右侧' { $env:WT_BGALIGN = 'right' } '左上' { $env:WT_BGALIGN = 'topLeft' }
        '右上' { $env:WT_BGALIGN = 'topRight' } '左下' { $env:WT_BGALIGN = 'bottomLeft' } '右下' { $env:WT_BGALIGN = 'bottomRight' }
    }

    Write-Host '  背景图浓淡 (0.15-0.9，越小越透；直接回车 = 默认 0.55): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    $v = $v.Trim(); if ($v) { $env:WT_BGOPACITY = $v }

    Write-Host '  背景图拉伸 1) 铺满并裁剪（推荐） 2) 拉伸填满（会变形） 3) 完整显示（留黑边） 4) 原始尺寸  (回车 = 不改): ' -NoNewline -ForegroundColor DarkCyan
    $v = Read-Answer
    switch ($v.Trim()) {
        '1' { $env:WT_BGSTRETCH = 'uniformToFill' } '2' { $env:WT_BGSTRETCH = 'fill' }
        '3' { $env:WT_BGSTRETCH = 'uniform' } '4' { $env:WT_BGSTRETCH = 'none' }
        '铺满并裁剪' { $env:WT_BGSTRETCH = 'uniformToFill' } '拉伸填满' { $env:WT_BGSTRETCH = 'fill' }
        '完整显示' { $env:WT_BGSTRETCH = 'uniform' } '原始尺寸' { $env:WT_BGSTRETCH = 'none' }
    }

    $aaText = @{ grayscale = '灰度柔和'; cleartype = '清晰锐利'; aliased = '像素风' }
    $adjText = @{ always = '总是修正'; indexed = '仅索引色'; never = '不修正' }
    $alignText = @{ center = '居中'; top = '顶部'; bottom = '底部'; left = '左侧'; right = '右侧'
                    topLeft = '左上'; topRight = '右上'; bottomLeft = '左下'; bottomRight = '右下' }
    $stretchText = @{ uniformToFill = '铺满并裁剪'; fill = '拉伸填满'; uniform = '完整显示'; none = '原始尺寸' }
    Write-Host ''
    Write-Host ("  高级外观: 行高=" + $(if ($env:WT_CELLHEIGHT) { $env:WT_CELLHEIGHT } else { '保持' }) +
                "  抗锯齿=" + $(if ($env:WT_AA) { $aaText[$env:WT_AA] } else { '保持' }) +
                "  颜色修正=" + $(if ($env:WT_ADJUST) { $adjText[$env:WT_ADJUST] } else { '保持' }) +
                "  字重=" + $(if ($env:WT_FONTWEIGHT) { if ($env:WT_FONTWEIGHT -eq 'bold') { '粗体' } else { '常规' } } else { '保持' }) +
                "  亚克力=" + $(if ($env:WT_ACRYLIC) { if ($env:WT_ACRYLIC -eq 'off') { '关（真透明）' } else { '开' } } else { '保持' })) -ForegroundColor Cyan
    if ($env:WT_BGALIGN -or $env:WT_BGOPACITY -or $env:WT_BGSTRETCH) {
        Write-Host ("  背景图  : 对齐=" + $(if ($env:WT_BGALIGN) { $alignText[$env:WT_BGALIGN] } else { '保持' }) +
                    "  浓淡=" + $(if ($env:WT_BGOPACITY) { $env:WT_BGOPACITY } else { '保持' }) +
                    "  拉伸=" + $(if ($env:WT_BGSTRETCH) { $stretchText[$env:WT_BGSTRETCH] } else { '保持' })) -ForegroundColor Cyan
    }
    Write-Host ''
}

# ---- 自适应前景色（对应 -adaptive / -adaptive off）----
Write-Host '是否启用自适应前景色（窗口透明时按背景明暗自动切换字体深浅）？' -ForegroundColor White
Write-Host '  [y] 开启    [off] 关闭并卸载    [N] 保持不变（默认，直接回车）' -ForegroundColor Gray
Write-Host '  > ' -NoNewline -ForegroundColor DarkCyan
$ansAw = Read-Answer
if ($null -eq $ansAw) { $ansAw = '' }
$ansAw = $ansAw.Trim().ToLower()
$awMode = 'keep'
if ($ansAw -eq 'y' -or $ansAw -eq 'yes' -or $ansAw -eq '是') { $awMode = 'on' }
elseif ($ansAw -eq 'off' -or $ansAw -eq 'o' -or $ansAw -eq '关') { $awMode = 'off' }
Write-Host ''
if ($awMode -eq 'on') { Write-Host '  自适应: 将开启' -ForegroundColor Cyan }
elseif ($awMode -eq 'off') { Write-Host '  自适应: 将关闭' -ForegroundColor Cyan }
else { Write-Host '  自适应: 保持不变' -ForegroundColor DarkGray }
Write-Host ''

# ---- 应用：起子进程真正执行，主进程循环播放动效 ----
$frames = @('|', '/', '—', '\')
$label  = '正在美化'

$psExe  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$outLog = Join-Path $env:TEMP ('wt_apply_' + [guid]::NewGuid().ToString('N') + '.out')
$errLog = Join-Path $env:TEMP ('wt_apply_' + [guid]::NewGuid().ToString('N') + '.err')

$child = $null
$ok = $false
$statusFile = Join-Path $env:TEMP ('wt_status_' + [guid]::NewGuid().ToString('N') + '.txt')
try {
    $env:WT_MODE = 'apply'
    $env:WT_FACE = $face
    $env:WT_STYLE = $chosenStyle
    $env:WT_TRANSPARENT = [string]$chosenTransp
    $env:WT_STATUS_FILE = $statusFile

    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        $child = Start-Process -FilePath $psExe `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"") `
            -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
            -NoNewWindow -PassThru
    }

    if ($child) {
        $i = 0
        $deadline = (Get-Date).AddSeconds(300)   # 最多等 5 分钟，避免卡在网络路径上一直转圈
        while (-not $child.HasExited) {
            Write-Host ("`r  {0} {1} · · · · · ·" -f $frames[$i % 4], $label) -NoNewline -ForegroundColor DarkCyan
            $i++
            if ((Get-Date) -gt $deadline) {
                try { $child.Kill() } catch { }
                throw '应用超时（5 分钟），已终止子进程；请检查背景图/字体路径是否在网络位置上'
            }
            Start-Sleep -Milliseconds 110
        }
        $child.WaitForExit()
        if (Test-Path -LiteralPath $statusFile) {
            $st = [System.IO.File]::ReadAllText($statusFile).Trim()
            $ok = ($st -eq 'OK')
        }
    }
    else {
        # 拿不到自身路径时退化为直接执行（动效只覆盖开始阶段）
        for ($k = 0; $k -lt 8; $k++) {
            Write-Host ("`r  {0} {1} · · · · · ·" -f $frames[$k % 4], $label) -NoNewline -ForegroundColor DarkCyan
            Start-Sleep -Milliseconds 90
        }
        Invoke-Beautify $face
        $ok = $true
    }
}
catch {
    Write-Host ''
    Bad "执行失败: $($_.Exception.Message)"
}
finally {
    Write-Host "`r" -NoNewline
    Write-Host (' ' * 46) -NoNewline
    Write-Host "`r" -NoNewline
    # 无论成功、失败还是 Ctrl+C 中断，都把临时产物清掉
    if ($catalogStage -and (Test-Path -LiteralPath $catalogStage)) {
        Remove-Item -LiteralPath $catalogStage -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($lg in @($outLog, $errLog, $statusFile)) {
        if ($lg) { Remove-Item -LiteralPath $lg -Force -ErrorAction SilentlyContinue }
    }
}

if ($ok) {
    Write-Host ('  美化完成（不透明度 ' + $chosenOpacity + '%），请重启终端') -ForegroundColor Green
    if ($awMode -eq 'on') {
        try {
            Write-Host ''
            Install-Adaptive
        } catch { Write-Host ('  自适应开启失败: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
    elseif ($awMode -eq 'off') {
        try { Write-Host ''; Remove-Adaptive } catch { }
    }
    if ($chosenStyle -eq 'linux') {
        Write-Host ('  新标签页的提示符将变为仿 Linux 样式：' + $env:USERNAME + '@' + $env:COMPUTERNAME.ToLower() + ':~$') -ForegroundColor DarkGray
    }
    else {
        Write-Host '  新标签页的提示符恢复为 Windows 默认（PS C:\...>）' -ForegroundColor DarkGray
    }
    if ($env:WT_CMDPROMPT -eq '1') {
        Write-Host '  cmd 也已设置；撤销请运行：terminal-setup.cmd --undo-cmd' -ForegroundColor DarkGray
    }
}
else {
    Write-Host '  美化未完全成功，输出如下：' -ForegroundColor Yellow
    foreach ($lg in @($outLog, $errLog)) {
        if ($lg -and (Test-Path -LiteralPath $lg)) {
            Get-Content -LiteralPath $lg -Encoding UTF8 -ErrorAction SilentlyContinue |
                Where-Object { $_.Trim() } | Select-Object -Last 12 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
    }
}
Write-Host ''

}
finally {
    # 退出前把窗口标题还原（#15），代码页由批处理的 :restore_cp 负责
    if ($__oldTitle) { try { $Host.UI.RawUI.WindowTitle = $__oldTitle } catch { } }
    if ($catalogStage -and (Test-Path -LiteralPath $catalogStage)) {
        Remove-Item -LiteralPath $catalogStage -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($lg in @($outLog, $errLog, $statusFile)) {
        if ($lg) { Remove-Item -LiteralPath $lg -Force -ErrorAction SilentlyContinue }
    }
}
