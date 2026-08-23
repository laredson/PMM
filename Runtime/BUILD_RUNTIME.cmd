@echo off
setlocal
cd /d "%~dp0"
where go.exe >nul 2>nul || (
  echo Go compiler not found. Install Go 1.23+ to rebuild PMMRuntime.exe.
  exit /b 2
)
set "CGO_ENABLED=0"
set "GOOS=windows"
set "GOARCH=amd64"
go build -trimpath -ldflags="-s -w" -o "..\PMMRuntime.exe" .
if errorlevel 1 exit /b %errorlevel%
echo PMMRuntime.exe built successfully.
exit /b 0
