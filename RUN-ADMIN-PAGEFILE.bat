@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM Enables automatic Windows pagefile ONLY (adds swap). No deletes.
setlocal
cd /d "%~dp0"
echo Requesting Administrator for pagefile enable (SAFE — no file deletes)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0scripts\enable-pagefile-safe.ps1\"' -Wait"
echo.
echo If the Admin window said REBOOT REQUIRED — reboot now, then re-run RUN.bat.
pause
