@echo off
setlocal
cd /d "%~dp0"
title Palworld Manager Merger v1.2 RC1 (PMM)
color 0B
cls
echo ================================================================
echo   PALWORLD MANAGER MERGER ^(PMM^)
echo   PMM Host supervised architecture - v1.2 RC1
echo ================================================================
echo.
if not exist "%~dp0PMM.exe" goto :hostmissing
"%~dp0PMM.exe" start
set "rc=%errorlevel%"
if "%rc%"=="0" goto :end
echo.
echo PMM returned exit code %rc%.
echo Host log: "%~dp0Logs\PMMHost.log"
echo Session diagnostics: "%~dp0Data\HostSessions"
echo AI handoffs: "%~dp0AI_HANDOFFS"
pause
goto :end
:hostmissing
echo PMM.exe is missing. You can use START_LEGACY.cmd for the previous PowerShell launcher.
pause
set "rc=90"
:end
endlocal & exit /b %rc%
