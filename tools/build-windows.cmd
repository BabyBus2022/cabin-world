@echo off
chcp 65001 >nul
cd /d "%~dp0.."
if "%~1"=="" (
  echo 用法: tools\build-windows.cmd "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
  exit /b 2
)
node tools\export-game.mjs "%~1" build\CabinWorld.exe
