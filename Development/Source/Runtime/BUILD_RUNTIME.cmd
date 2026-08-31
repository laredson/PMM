@echo off
call "%~dp0\..\..\Scripts\build\BUILD_RUNTIME.cmd"
exit /b %errorlevel%
