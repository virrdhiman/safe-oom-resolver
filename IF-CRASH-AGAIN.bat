@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM One entry when crashing happens again after pagefile fix.
setlocal EnableExtensions
title If Crash Happens Again - Safe Resolve
color 0E
cd /d "%~dp0"

echo.
echo  ============================================================
echo   SAME CRASH AGAIN? SAFE RESOLVE (no data / chat loss)
echo  ============================================================
echo   Step 1: Diagnose
echo   Step 2: Release absorbing processes (keep editor + OS)
echo   Step 3: Tell you if pagefile/reboot still needed
echo  ============================================================
echo.

call "%~dp0RELEASE-MEMORY.bat"
set "EC=%ERRORLEVEL%"

echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0resolve.ps1" -SkipPagefileHint
echo.
echo  If diagnose still says UNSAFE and commit limit ~= RAM:
echo    run RUN-ADMIN-PAGEFILE.bat as Admin, then reboot.
echo.
pause
exit /b %EC%
