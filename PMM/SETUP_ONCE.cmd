@echo off
setlocal
cd /d "%~dp0"
where pwsh.exe >nul 2>nul
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1"
)
if errorlevel 1 (
  echo.
  echo Setup failed. The error above is the actionable error; nothing runs in the background.
  pause
  exit /b 1
)
echo.
pause
endlocal
