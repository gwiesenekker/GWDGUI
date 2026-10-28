@echo off
rem Builds gwdgui.exe on Windows with Lazarus (the Windows build mode).
rem
rem Usage:  build.bat [path\to\lazbuild.exe]
rem
rem The Windows build mode embeds MANUAL.md and the Git commit (shown in
rem Help > About); install Git for Windows and have git on PATH for the commit.
rem Lazarus is found as the argument, the LAZBUILD environment variable,
rem lazbuild on PATH, or a standard installation folder, in that order.
rem A running gwdgui.exe can be rebuilt: the old executable is renamed to
rem gwdgui.old.exe first and restored if the build fails.
setlocal EnableExtensions
cd /d "%~dp0"

if not "%~1"=="" set "LAZBUILD=%~1"
if not defined LAZBUILD (
  for /f "delims=" %%I in ('where lazbuild.exe 2^>nul') do (
    if not defined LAZBUILD set "LAZBUILD=%%I"
  )
)
if "%LAZBUILD%"=="" if exist "C:\lazarus\lazbuild.exe" set "LAZBUILD=C:\lazarus\lazbuild.exe"
if "%LAZBUILD%"=="" if exist "%ProgramFiles%\Lazarus\lazbuild.exe" set "LAZBUILD=%ProgramFiles%\Lazarus\lazbuild.exe"
if "%LAZBUILD%"=="" if exist "%ProgramFiles(x86)%\Lazarus\lazbuild.exe" set "LAZBUILD=%ProgramFiles(x86)%\Lazarus\lazbuild.exe"
if "%LAZBUILD%"=="" if exist "%LOCALAPPDATA%\lazarus\lazbuild.exe" set "LAZBUILD=%LOCALAPPDATA%\lazarus\lazbuild.exe"
if not defined LAZBUILD (
  echo lazbuild.exe not found. Pass its path as the first argument, for example:
  echo   build.bat C:\lazarus\lazbuild.exe
  exit /b 1
)
if not exist "%LAZBUILD%" (
  echo lazbuild.exe not found at "%LAZBUILD%".
  exit /b 1
)

where git.exe >nul 2>nul
if errorlevel 1 (
  echo Warning: git is not on PATH; Help ^> About will report the commit as unavailable.
)
if not exist "draughts.ttf" (
  echo Warning: draughts.ttf is missing; keep it beside gwdgui.exe.
)

rem Keep the previous executable until the new one is linked.
if exist "gwdgui.old.exe" del /f /q "gwdgui.old.exe" >nul 2>nul
set "MOVED_OLD="
if exist "gwdgui.exe" (
  move /y "gwdgui.exe" "gwdgui.old.exe" >nul
  if errorlevel 1 (
    echo Could not rename gwdgui.exe; close GWDGUI or remove gwdgui.old.exe and retry.
    exit /b 1
  )
  set "MOVED_OLD=1"
)

echo Building with "%LAZBUILD%" ...
"%LAZBUILD%" --build-all --build-mode=Windows --no-write-project gwdgui.lpi
set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" goto failed
if not exist "gwdgui.exe" goto failed

if defined MOVED_OLD del /f /q "gwdgui.old.exe" >nul 2>nul
echo Built %~dp0gwdgui.exe
exit /b 0

:failed
echo Build failed (lazbuild exit code %RESULT%).
if defined MOVED_OLD (
  if not exist "gwdgui.exe" move /y "gwdgui.old.exe" "gwdgui.exe" >nul
  echo The previous gwdgui.exe was kept.
)
if "%RESULT%"=="0" exit /b 1
exit /b %RESULT%
