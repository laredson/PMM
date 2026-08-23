@echo off
setlocal
cd /d "%~dp0"
set GOOS=windows
set GOARCH=amd64
go build -trimpath -ldflags "-s -w" -o "..\PMM.exe" .
endlocal
