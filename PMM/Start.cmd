@echo off
setlocal
cd /d "%~dp0"
title Palworld Manager Merger v1.1 CLEAN RC1 (PMM)
color 0B
cls
echo ================================================================
echo   PALWORLD MANAGER MERGER ^(PMM^)
echo   Palworld Mod Manager + Compatibility Merger
echo   TEST CANDIDATE: v1.1 CLEAN RC1
echo ================================================================
echo.
where pwsh.exe >nul 2>nul
if %errorlevel%==0 (
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1" -IfNeeded
  if errorlevel 1 goto :setupfailed
  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SmokeTest.ps1" -Quiet
  if errorlevel 1 goto :smokefailed
  pwsh.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PalModMerger.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-Dependencies.ps1" -IfNeeded
  if errorlevel 1 goto :setupfailed
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SmokeTest.ps1" -Quiet
  if errorlevel 1 goto :smokefailed
  powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PalModMerger.ps1"
)
goto :end

:setupfailed
echo.
echo PMM dependency verification/repair failed. Review the error above.
pause
goto :end

:smokefailed
echo.
echo PMM validation failed. Review the error above.
pause

:end
endlocal
