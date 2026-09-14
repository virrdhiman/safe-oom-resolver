@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM Frees SAFE orphan memory absorbers only. Never deletes data/chats.
setlocal EnableExtensions
cd /d "%~dp0"
call "%~dp0RELEASE-MEMORY.bat" %*
exit /b %ERRORLEVEL%
