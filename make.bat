@echo off
setlocal
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
if [%1]==[nuke] (
	del "%ROOT%\lau\*.lua"
) else (
	pushd "%ROOT%"
	luajit lau.lua -f lau.lau . %1
	popd
	rem pause
	pushd "%ROOT%"
	luajit run-test.lua
	popd
)
endlocal
