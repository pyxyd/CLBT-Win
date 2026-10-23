@echo off
rem  ====================================================================
rem   CLBT 代码签名脚本
rem
rem   用法：
rem     sign.cmd                         签 dist\install.exe
rem     sign.cmd <exe 路径>
rem     sign.cmd <exe 路径> <证书指纹>
rem     sign.cmd <exe 路径> pfx <pfx 路径> <密码>
rem
rem   证书从哪来（三条路，见 README_SIGN.md）：
rem     1) 自签名（仅内测，对外分发无意义）
rem     2) Certum Open Source Code Signing / SignPath（开源低成本）
rem     3) OV / EV 商业证书（企业资质；EV 才立刻消 SmartScreen）
rem
rem   注意：签完必须打时间戳，否则证书到期后签名一起失效。
rem  ====================================================================
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

set "SIGNTOOL=C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
if not exist "%SIGNTOOL%" (
    rem 兜底：自动找最新的 SDK 版本
    for /f "delims=" %%i in ('dir /b /o-n "C:\Program Files (x86)\Windows Kits\10\bin\*x64\signtool.exe" 2^>nul') do (
        set "SIGNTOOL=C:\Program Files (x86)\Windows Kits\10\bin\%%i"
        goto :found
    )
    echo [XX] 找不到 signtool.exe，请安装 Windows SDK
    exit /b 1
)
:found

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%~dp0dist\install.exe"
if not exist "%TARGET%" (
    echo [XX] 文件不存在: %TARGET%
    exit /b 1
)

set "TS=http://timestamp.digicert.com"

echo.
echo   signtool : %SIGNTOOL%
echo   目标文件 : %TARGET%
echo   时间戳   : %TS%
echo.

if /i "%~2"=="pfx" (
    echo   [模式] PFX 文件签名
    "%SIGNTOOL%" sign /fd SHA256 /td SHA256 /tr "%TS%" /f "%~3" /p "%~4" "%TARGET%"
    goto :verify
)

if not "%~2"=="" (
    echo   [模式] 证书存储 + 指定指纹
    "%SIGNTOOL%" sign /fd SHA256 /td SHA256 /tr "%TS%" /sha1 "%~2" "%TARGET%"
    goto :verify
)

echo   [模式] 自动挑选已安装的代码签名证书
"%SIGNTOOL%" sign /fd SHA256 /td SHA256 /tr "%TS%" /a "%TARGET%"

:verify
echo.
echo ==== 验证 ====
"%SIGNTOOL%" verify /pa /v "%TARGET%"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
    echo [OK] 签名有效
) else (
    echo [XX] 验证失败，退出码 %RC%
)
endlocal & exit /b %RC%
