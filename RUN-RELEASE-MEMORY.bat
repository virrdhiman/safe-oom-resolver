@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM Frees SAFE orphan memory absorbers only. Never deletes data/chats.
REM Never kills the editor, desktop agents, OS, Postgres/Redis, or normal Chrome.
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"

echo.
echo  ============================================================
echo   SAFE MEMORY RELEASE - if OOM pressure returns
echo  ============================================================
echo   STOPS only: orphan Prisma/Node db:push leftovers,
echo               Playwright/Puppeteer Chromium leftovers
echo   NEVER: editor, chats, desktop agents, OS, DB, your Chrome
echo   NEVER deletes files or agent transcripts
echo  ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release-safe-memory.ps1" %*
set "EC=%ERRORLEVEL%"

echo.
echo  Re-check memory:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\diagnose.ps1"

echo.
echo  Log: %~dp0logs\release-memory.log
echo.
pause
exit /b %EC%
