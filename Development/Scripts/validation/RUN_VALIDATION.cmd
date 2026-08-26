@echo off
setlocal
cd /d "%~dp0\..\..\.."
echo ================================================================
echo   PALWORLD MANAGER MERGER - REPOSITORY VALIDATION
echo   PMM 1.2.1 - Guided Flow stable repository baseline
echo ================================================================
echo.
"PMM\Engine\PMMRuntime.exe" self-test
if errorlevel 1 exit /b %errorlevel%
where powershell.exe >nul 2>nul || (echo powershell.exe not found.& exit /b 2)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Development\Scripts\validation\Validate-v1.2.ps1"
if errorlevel 1 exit /b %errorlevel%
echo.
echo PMM repository validation PASSED.
pause
endlocal & exit /b 0
