@echo off
pushd "%~dp0"
"runtime\node.exe" "tools\resource-kit.mjs" export
set "rc=%errorlevel%"
popd
pause
exit /b %rc%
