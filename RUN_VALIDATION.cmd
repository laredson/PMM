@echo off
setlocal
cd /d "%~dp0"
title Palworld Manager Merger v1.2 RC1 - Release Validation
color 0E
cls
echo ================================================================
echo   PALWORLD MANAGER MERGER - RELEASE VALIDATION
echo   PMM 1.2 RC1 - Host + Runtime + FIX4 regression
echo ================================================================
echo.
if not exist "%~dp0PMMRuntime.exe" (
  echo PMMRuntime.exe is missing.
  exit /b 2
)
"%~dp0PMMRuntime.exe" self-test
if errorlevel 1 (
  echo PMMRuntime native self-test FAILED.
  exit /b %errorlevel%
)
where pwsh.exe >nul 2>nul
if errorlevel 1 goto :windowsps
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SmokeTest.ps1"
goto :after
:windowsps
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SmokeTest.ps1"
:after
set "rc=%errorlevel%"
echo.
if "%rc%"=="0" (echo PMM release validation PASSED.) else (echo PMM release validation FAILED.)
echo Validation log: "%~dp0Logs\Validation.log"
pause
endlocal & exit /b %rc%
