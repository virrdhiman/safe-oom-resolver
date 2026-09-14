@echo off
REM PRJs runner | platform: windows | scope: repo-local
setlocal EnableExtensions
title Safe OOM Resolver — no data loss
color 0B
cd /d "%~dp0"

echo.
echo  ============================================================
echo   SAFE OOM RESOLVER — diagnose + fix without deleting data
echo  ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0resolve.ps1" %*
set "EC=%ERRORLEVEL%"
echo.
if not "%EC%"=="0" (
  echo  Exit code %EC% — see messages above.
  echo  If pagefile must be enabled: right-click RUN-ADMIN-PAGEFILE.bat
) else (
  echo  Done.
)
echo.
pause
exit /b %EC%
