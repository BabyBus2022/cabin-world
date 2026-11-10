@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
title Cabin World bridge
set "NODE=node"
if exist "%~dp0runtime\node.exe" set "NODE=%~dp0runtime\node.exe"
"%NODE%" -e "process.exit(Number(process.versions.node.split('.')[0])>=18?0:1)" >nul 2>nul
if errorlevel 1 (
  echo.
  echo  [小屋世界] 需要 Node.js 18 或更新版本。
  echo  [Cabin World] Node.js 18+ is required.
  echo  请到 https://nodejs.org 下载 LTS 版安装，或把 node.exe 放到 runtime\node.exe
  echo.
  pause
  exit /b 1
)
"%NODE%" "%~dp0bridge\bridge.mjs" --config "%~dp0bridge\bridge.config.json"
echo.
pause
