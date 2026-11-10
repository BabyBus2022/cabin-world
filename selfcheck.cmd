@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
title Cabin World self-check
set "NODE=node"
if exist "%~dp0runtime\node.exe" set "NODE=%~dp0runtime\node.exe"
"%NODE%" -e "process.exit(0)" >nul 2>nul
if errorlevel 1 (
  echo  [小屋世界] 没有找到 Node.js：请到 https://nodejs.org 安装 18 或更新版本。
  pause
  exit /b 1
)
"%NODE%" "%~dp0bridge\selfcheck.mjs" --config "%~dp0bridge\bridge.config.json" --live %*
echo.
pause
