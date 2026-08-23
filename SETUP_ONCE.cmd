@echo off
setlocal
cd /d "%~dp0"
title Palworld Manager Merger v1.2 RC1 - Dependency Setup
if not exist "%~dp0PMMRuntime.exe" (
  echo PMMRuntime.exe is missing.
  pause
  exit /b 20
)
"%~dp0PMMRuntime.exe" dependencies ensure
set "rc=%errorlevel%"
if not "%rc%"=="0" (
  echo.
  echo Setup failed with exit code %rc%.
  echo Support log: "%~dp0Logs\PalModMerger.log"
  pause
  endlocal & exit /b %rc%
)
echo.
echo PMM dependencies are ready.
pause
endlocal & exit /b 0
