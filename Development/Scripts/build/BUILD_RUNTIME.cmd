@echo off
setlocal
set "ROOT=%~dp0\..\..\.."
set "FRESH=%TEMP%\PMM_runtime_fresh_%RANDOM%%RANDOM%.exe"
echo WARNING: Development\Source is the restructured 1.2.1 source snapshot.
echo Do not overwrite the known-good Guided Flow runtime unless source reconciliation is intentional.
cd /d "%ROOT%\Development\Source\Runtime"
where go >nul 2>nul || (echo Go compiler not found.& exit /b 2)
set "CGO_ENABLED=0"
set "GOOS=windows"
set "GOARCH=amd64"
go build -trimpath -ldflags="-s -w" -o "%FRESH%" . || exit /b 1
cd /d "%ROOT%\Development\Source\PEIcon"
go run inject.go -exe "%FRESH%" -ico "%ROOT%\PMM\Resources\UI\PMM.ico" || exit /b 1
echo Build created at: %FRESH%
echo It was NOT copied over PMM\Engine\PMMRuntime.exe automatically.
exit /b 0
