@echo off
setlocal
cd /d "%~dp0"
title Palworld Manager Merger v1.1.1 (PMM)
color 0B
cls
echo ================================================================
echo   PALWORLD MANAGER MERGER ^(PMM^)
echo   Palworld Mod Manager + Compatibility Merger
echo   RELEASE: v1.1.1
echo ================================================================
echo.
where pwsh.exe >nul 2>nul
if errorlevel 1 goto :windowsps

pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1" -IfNeeded
if errorlevel 1 goto :setupfailed
pwsh.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PalModMerger.ps1"
if errorlevel 1 goto :appfailed
goto :end

:windowsps
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1" -IfNeeded
if errorlevel 1 goto :setupfailed
powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PalModMerger.ps1"
if errorlevel 1 goto :appfailed
goto :end

:setupfailed
echo.
echo PMM dependency verification/repair failed. Review the error above.
echo Support log: "%~dp0Logs\PalModMerger.log"
pause
goto :end

:appfailed
echo.
echo PMM exited unexpectedly. Review the error above.
echo Support log: "%~dp0Logs\PalModMerger.log"
pause

:end
endlocal
