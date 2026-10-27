@echo off
setlocal
rem Lazarus supplies its configured FPC executable as the first argument.
set "ROOT=%~dp0.."
set "OUT=%ROOT%\lib\build-info"
if not exist "%OUT%" mkdir "%OUT%"
if errorlevel 1 exit /b 1
"%~1" -B "-FU%OUT%" "-FE%OUT%" "-o%OUT%\generate_build_info.exe" "%~dp0generate_build_info.pas"
if errorlevel 1 exit /b 1
"%OUT%\generate_build_info.exe" "%ROOT%" "%OUT%\gwdgui-build.inc"
if errorlevel 1 exit /b 1
exit /b 0
