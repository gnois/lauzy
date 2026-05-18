@echo off
setlocal
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
if [%1]==[nuke] (
	del "%ROOT%\lt\*.lua"
) else (
	pushd "%ROOT%"
	luajit lt.lua -f lt.lt . %1
	popd
	rem pause
	pushd "%ROOT%"
	luajit run-test.lua
	popd
)
endlocal
