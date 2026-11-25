@echo off
setlocal
cd /d "%~dp0"
if /I "%~1"=="--ai-upgrade" (
  for /f "delims=" %%S in ('runtime\node.exe tools\setup.mjs status') do if "%%S"=="ready" goto choices
)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1"
exit /b %errorlevel%
:choices
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0choose-modules.ps1"
