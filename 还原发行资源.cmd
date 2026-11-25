@echo off
pushd "%~dp0"
"runtime\node.exe" "tools\resource-kit.mjs" restore
set "rc=%errorlevel%"
popd
pause
exit /b %rc%
