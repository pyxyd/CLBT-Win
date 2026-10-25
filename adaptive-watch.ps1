# =====================================================================
#  自适应前景色守护进程
#  当窗口足够透明（不透明度 < 75%）时，实时采样终端窗口周围的像素：
#    · 亮背景 -> 用深色文字
#    · 暗背景 -> 用浅色文字
#  只在「判断结果发生变化」时才改写 settings.json（Terminal 会热加载）
#
#  用法：powershell -NoProfile -File adaptive-watch.ps1 [-Once] [-ForceLum 0-255]
# =====================================================================
param(
    [string]$SettingsPath = '',
    [int]$IntervalMs = 2000,
    [int]$Threshold = 128,        # 感知亮度高于此值视为"亮背景"
    [int]$ForceLum = -1,          # 测试用：强制亮度，跳过采样
    [switch]$Once,                # 只跑一轮（测试用）
    [switch]$Probe,               # 只采样并打印亮度，不写配置
    [int]$MaxIdleSec = 60         # 连续这么多秒找不到终端窗口就退出
)

$ErrorActionPreference = 'Stop'
$LOCK_NAME = 'Global\CLBT_AdaptiveWatch'

# ---- 前景色定义 ----
$FG_LIGHT = '#D3D7CF'   # 暗背景用浅色字（默认 Tango 前景）
$FG_DARK  = '#14161A'   # 亮背景用深色字
$SCHEME   = 'Linux (Tango)'

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class AW {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
'@

function Get-SettingsPath {
    if ($SettingsPath) { return $SettingsPath }
    if ($env:WT_SETTINGS_PATH) { return $env:WT_SETTINGS_PATH }
    $c = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    return ($c | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
}

function Get-FileJson([string]$path) {
    $raw = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
    # 去掉 // 与 /* */ 注释（保留字符串内的 //）
    $sb = New-Object System.Text.StringBuilder
    $inStr = $false; $esc = $false; $i = 0
    while ($i -lt $raw.Length) {
        $ch = $raw[$i]
        if ($inStr) {
            [void]$sb.Append($ch)
            if ($esc) { $esc = $false }
            elseif ($ch -eq '\') { $esc = $true }
            elseif ($ch -eq '"') { $inStr = $false }
            $i++
        }
        elseif ($ch -eq '"') { $inStr = $true; [void]$sb.Append($ch); $i++ }
        elseif ($ch -eq '/' -and ($i + 1) -lt $raw.Length -and $raw[$i + 1] -eq '/') {
            while ($i -lt $raw.Length -and $raw[$i] -ne "`n") { $i++ }
        }
        elseif ($ch -eq '/' -and ($i + 1) -lt $raw.Length -and $raw[$i + 1] -eq '*') {
            $i += 2
            while (($i + 1) -lt $raw.Length -and -not ($raw[$i] -eq '*' -and $raw[$i + 1] -eq '/')) { $i++ }
            $i += 2
        }
        else { [void]$sb.Append($ch); $i++ }
    }
    return ($sb.ToString() | ConvertFrom-Json)
}

function Get-TerminalRect {
    # 取当前前台窗口；若它像终端（高宽比合理且可见）就用它
    $h = [AW]::GetForegroundWindow()
    if ($h -eq [IntPtr]::Zero) { return $null }
    $r = New-Object AW+RECT
    if (-not [AW]::GetWindowRect($h, [ref]$r)) { return $null }
    $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
    if ($w -lt 200 -or $ht -lt 150) { return $null }
    return [pscustomobject]@{ Hwnd = $h; Left = $r.Left; Top = $r.Top; Right = $r.Right; Bottom = $r.Bottom; W = $w; H = $ht }
}

function Get-BackdropLuminance($rect) {
    # 采样窗口外圈一圈像素（桌面/其它窗口），用来推断当前区域的明暗。
    # 终端本身不透明地画自己的内容，所以不能从窗口内部取背景。
    $band = 14
    $bmp = New-Object System.Drawing.Bitmap 220, 60
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $sumL = 0; $n = 0

    try {
        # 左侧与右侧竖条
        foreach ($x in @(($rect.Left - $band), ($rect.Right + $band))) {
            for ($k = 0; $k -lt 6; $k++) {
                $y = $rect.Top + [int]($rect.H * ($k + 0.5) / 6)

                try {
                    $g.CopyFromScreen($x, $y, $k * 20, 0, (New-Object System.Drawing.Size 12, 8))
                    $c = $bmp.GetPixel($k * 20 + 4, 3)
                    $sumL += (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B)
                    $n++
                } catch { }
            }
        }
        # 上方与下方横条
        foreach ($y in @(($rect.Top - $band), ($rect.Bottom + $band))) {
            for ($k = 0; $k -lt 6; $k++) {
                $x = $rect.Left + [int]($rect.W * ($k + 0.5) / 6)
                try {
                    $g.CopyFromScreen($x, $y, $k * 20, 20, (New-Object System.Drawing.Size 12, 8))
                    $c = $bmp.GetPixel($k * 20 + 4, 23)
                    $sumL += (0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B)
                    $n++
                } catch { }
            }
        }
    } finally { $g.Dispose(); $bmp.Dispose() }

    if ($n -eq 0) { return -1 }
    return [int]($sumL / $n)
}

function Get-Opacity($json) {
    try {
        $o = $json.profiles.defaults.opacity
        if ($null -eq $o) { return 100 }
        return [int]$o
    } catch { return 100 }
}

function Set-Foreground([string]$path, $json, [string]$colorHex) {
    $changed = $false
    foreach ($s in @($json.schemes)) {
        if ($null -ne $s -and $s.name -eq $SCHEME) {
            if ($s.foreground -ne $colorHex) { $s.foreground = $colorHex; $changed = $true }
        }
    }
    # cursorColor 跟随，避免深色字配浅色光标
    foreach ($s in @($json.schemes)) {
        if ($null -ne $s -and $s.name -eq $SCHEME) {
            if ($s.cursorColor -ne $colorHex) { $s.cursorColor = $colorHex; $changed = $true }
        }
    }
    if ($changed) {
        $out = $json | ConvertTo-Json -Depth 32
        # 原子写入：先写临时文件再替换，避免 Terminal 读到半截 JSON
        $tmp = $path + '.clbt-tmp'
        [System.IO.File]::WriteAllText($tmp, $out, (New-Object System.Text.UTF8Encoding($false)))
        try {
            [System.IO.File]::Replace($tmp, $path, $null)
        } catch {
            Copy-Item -LiteralPath $tmp -Destination $path -Force
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    return $changed
}

# ---------------------------------------------------------------------
# 单实例锁
# ---------------------------------------------------------------------
$created = $false
$mutex = New-Object System.Threading.Mutex($true, $LOCK_NAME, [ref]$created)
if (-not $created) { exit 0 }

$lastMode = $null
$idleTicks = 0
try {
    $stopFlag = Join-Path (Split-Path -Parent $PSCommandPath) 'adaptive-watch.stop'
    while ($true) {
        # 优雅退出：CLBT -adaptive off 会写这个标志文件
        if (Test-Path -LiteralPath $stopFlag) {
            Remove-Item -LiteralPath $stopFlag -Force -ErrorAction SilentlyContinue
            break
        }

        $sp = Get-SettingsPath
        if (-not $sp) { Start-Sleep -Milliseconds $IntervalMs; if ($Once) { break }; continue }

        try { $json = Get-FileJson $sp } catch { $json = $null }
        if ($null -eq $json) {
            # settings.json 正在被终端改写或格式异常，跳过这一轮
            if ($Once) { break }
            Start-Sleep -Milliseconds $IntervalMs
            continue
        }
        $opacity = Get-Opacity $json
        $enabled = ($opacity -lt 75)   # 不透明度 < 75% 才启用自适应

        if ($enabled) {
            if ($ForceLum -ge 0) { $lum = $ForceLum }
            else {
                $rect = Get-TerminalRect
                if ($rect) { $lum = Get-BackdropLuminance $rect }
                else { $lum = -1; $idleTicks++ }
            }

            if ($Probe) {
                Write-Output ("backdrop luminance = " + $lum)
                break
            }

            if ($lum -ge 0) {
                $idleTicks = 0
                $mode = if ($lum -ge $Threshold) { 'dark-text' } else { 'light-text' }
                if ($mode -ne $lastMode) {
                    $fg = if ($mode -eq 'dark-text') { $FG_DARK } else { $FG_LIGHT }
                    if (Set-Foreground $sp $json $fg) {
                        Write-Output ("[{0}] 背景亮度 {1} -> {2} {3}" -f (Get-Date -Format 'HH:mm:ss'), $lum, $mode, $fg)
                    }
                    $lastMode = $mode
                }
            }
        }

        # 找不到终端窗口太久就退出，避免残留进程
        if ($idleTicks -gt [int]($MaxIdleSec / [Math]::Max(1, $IntervalMs / 1000))) { break }

        if ($Once) { break }
        Start-Sleep -Milliseconds $IntervalMs
    }
}
finally {
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
}
