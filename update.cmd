@echo off
rem Independent 1.1 installation choices. See INSTALL-AI.md. Requires Node.js 18+.
cd /d "%~dp0"
node bridge\update-cli.mjs %*
pause
