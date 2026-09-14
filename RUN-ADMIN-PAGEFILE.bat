@echo off
REM PRJs runner | platform: windows | scope: repo-local
REM Enables a real C:\pagefile.sys (adds swap only). No deletes.
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "logs" mkdir "logs"

echo.
echo  ============================================================
echo   SAFE PAGEFILE ENABLE - adds virtual memory only
echo   Does NOT delete system files, projects, DB, or chats
echo  ============================================================
echo.
echo  Windows will ask for Administrator permission (UAC).
echo  Click Yes. If you click No, this will fail.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=Join-Path '%~dp0' 'scripts\enable-pagefile-safe.ps1'; $log=Join-Path '%~dp0' 'logs\pagefile-enable.log'; try { $proc=Start-Process -FilePath powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$p); if ($null -eq $proc) { 'UAC cancelled or elevation failed' | Tee-Object -FilePath $log -Append; exit 1 }; exit $proc.ExitCode } catch { $_ | Out-String | Tee-Object -FilePath $log -Append; exit 1 }"

set "EC=%ERRORLEVEL%"
echo.
echo  Exit code: %EC%
echo.
if exist "%~dp0logs\pagefile-enable.log" (
  echo  --- last log lines ---
  powershell.exe -NoProfile -Command "Get-Content -Path '%~dp0logs\pagefile-enable.log' -Tail 20"
  echo  ----------------------
)
echo.
if not "%EC%"=="0" (
  echo  FAILED. Common causes:
  echo    1^) You clicked No on the UAC prompt
  echo    2^) Antivirus blocked elevated PowerShell
  echo  Fix: right-click scripts\enable-pagefile-safe.ps1 -^> Run with PowerShell as Admin
  echo  Or open Admin PowerShell and run:
  echo    powershell -ExecutionPolicy Bypass -File "%~dp0scripts\enable-pagefile-safe.ps1"
) else (
  echo  SUCCESS - please REBOOT now, then run RUN.bat
)
echo.
pause
exit /b %EC%
