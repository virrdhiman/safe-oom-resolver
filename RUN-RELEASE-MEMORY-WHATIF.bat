@echo off
REM Preview only - lists what would be stopped; changes nothing
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release-safe-memory.ps1" -WhatIf
pause
