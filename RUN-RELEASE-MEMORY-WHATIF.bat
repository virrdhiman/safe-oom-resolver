@echo off
REM Preview only
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release-memory-safe.ps1" -WhatIf
pause
