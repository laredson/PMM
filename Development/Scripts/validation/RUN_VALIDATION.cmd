@echo off
setlocal
cd /d "%~dp0\..\..\.."
echo ================================================================
echo   PALWORLD MANAGER MERGER - REPOSITORY VALIDATION
echo   PMM 1.3.0 RC30 - lean AI, validation and idle-performance candidate
echo ================================================================
echo.
"PMM\Engine\PMMRuntime.exe" self-test
if errorlevel 1 exit /b %errorlevel%
where powershell.exe >nul 2>nul || (echo powershell.exe not found.& exit /b 2)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Development\Scripts\validation\Validate-v1.3.ps1"
if errorlevel 1 exit /b %errorlevel%
echo.
echo PMM repository validation PASSED.
pause
endlocal & exit /b 0
