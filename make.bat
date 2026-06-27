@echo off
setlocal
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
pushd "%ROOT%"

luajit lau.lua -f lau.lau .
if errorlevel 1 goto :fail

luajit build.lua
if errorlevel 1 goto :fail

popd
endlocal
exit /b 0

:fail
set "CODE=%errorlevel%"
popd
endlocal
exit /b %CODE%
