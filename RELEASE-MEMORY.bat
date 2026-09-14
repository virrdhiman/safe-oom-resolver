@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM If OOM/editor crash pressure returns: free absorbing processes safely.
REM NEVER deletes data/chats/OS files. NEVER kills the editor.
setlocal EnableExtensions EnableDelayedExpansion
title Safe Memory Release - keep chats and data
color 0B
cd /d "%~dp0"
if not exist "logs" mkdir "logs"

echo.
echo  ============================================================
echo   IF CRASH PRESSURE RETURNS - SAFE MEMORY RELEASE
echo  ============================================================
echo   - Does NOT delete files, chats, DB, or OS components
echo   - Does NOT kill the editor (agent chats stay)
echo   - Stops leftover Node/Bun/Playwright memory hogs
echo   - Optional: browsers (Chrome/Edge) - tabs close, data kept
echo  ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\diagnose.ps1"
echo.

set "BROWSER=N"
set /p BROWSER=Also stop Chrome/Edge/Brave/Firefox? [Y/N] (default N): 
if /I "%BROWSER%"=="Y" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release-memory-safe.ps1" -IncludeBrowsers
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release-memory-safe.ps1"
)
set "EC=%ERRORLEVEL%"

echo.
echo  --- diagnose after release ---
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\diagnose.ps1"

echo.
if exist "%~dp0logs\release-memory.log" (
  echo  Log: %~dp0logs\release-memory.log
  powershell.exe -NoProfile -Command "Get-Content -Path '%~dp0logs\release-memory.log' -Tail 15"
)
echo.
if not "%EC%"=="0" (
  echo  Still tight on memory. Try again and answer Y for browsers,
  echo  or run RUN-ADMIN-PAGEFILE.bat + reboot if pagefile inactive.
) else (
  echo  Done. Safe to retry your project / agent work.
)
echo.
pause
exit /b %EC%
