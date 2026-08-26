@echo off
call "%~dp0\..\..\Scripts\build\BUILD_HOST.cmd"
exit /b %errorlevel%
