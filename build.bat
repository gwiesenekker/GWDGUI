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

set "CANDIDATE_DIR=lib\candidate\"

rem Repair an interrupted replacement: only the previous executable is left.
if not exist "gwdgui.exe" if exist "gwdgui.old.exe" (
  move /y "gwdgui.old.exe" "gwdgui.exe" >nul
  if errorlevel 1 (
    echo gwdgui.exe is missing and gwdgui.old.exe could not be renamed back.
    echo Rename gwdgui.old.exe to gwdgui.exe and retry.
    exit /b 1
  )
  echo Restored gwdgui.exe from gwdgui.old.exe ^(an earlier build was interrupted^).
)

if not exist "%CANDIDATE_DIR%" mkdir "%CANDIDATE_DIR%"
if exist "%CANDIDATE_DIR%gwdgui.exe" del /f /q "%CANDIDATE_DIR%gwdgui.exe" >nul 2>nul
if exist "%CANDIDATE_DIR%gwdgui.exe" (
  echo Could not remove the old build output %CANDIDATE_DIR%gwdgui.exe.
  exit /b 1
)

echo Building with "%LAZBUILD%" ...
set "GWDGUI_BUILD_DIR=%CANDIDATE_DIR%"
rem call also runs a lazbuild wrapper script (and the build check's stand-in).
call "%LAZBUILD%" --build-all --build-mode=Windows --no-write-project gwdgui.lpi
set "RESULT=%ERRORLEVEL%"
set "GWDGUI_BUILD_DIR="
if not "%RESULT%"=="0" goto failed
if not exist "%CANDIDATE_DIR%gwdgui.exe" goto failed

rem Replace gwdgui.exe. gwdgui.exe is good here (only a successful build is
rem ever moved in), so a backup left beside it by an earlier build can go.
if exist "gwdgui.old.exe" del /f /q "gwdgui.old.exe" >nul 2>nul
if exist "gwdgui.old.exe" (
  echo gwdgui.old.exe is still in use ^(an older GWDGUI is running^); close it and retry.
  echo The new build is in %CANDIDATE_DIR%gwdgui.exe; gwdgui.exe was not changed.
  exit /b 1
)
set "MOVED_OLD="
if exist "gwdgui.exe" (
  move /y "gwdgui.exe" "gwdgui.old.exe" >nul
  if errorlevel 1 (
    echo Could not rename gwdgui.exe; close GWDGUI and retry.
    echo The new build is in %CANDIDATE_DIR%gwdgui.exe; gwdgui.exe was not changed.
    exit /b 1
  )
  set "MOVED_OLD=1"
)
move /y "%CANDIDATE_DIR%gwdgui.exe" "gwdgui.exe" >nul
if errorlevel 1 goto publishfailed
if defined MOVED_OLD del /f /q "gwdgui.old.exe" >nul 2>nul
echo Built %~dp0gwdgui.exe
exit /b 0

:publishfailed
echo Could not move the new build into place.
if not defined MOVED_OLD exit /b 1
move /y "gwdgui.old.exe" "gwdgui.exe" >nul
if errorlevel 1 (
  echo The previous executable is gwdgui.old.exe; rename it to gwdgui.exe.
  exit /b 1
)
echo The previous gwdgui.exe was kept.
exit /b 1

:failed
echo Build failed ^(lazbuild exit code %RESULT%^); gwdgui.exe was not changed.
if "%RESULT%"=="0" exit /b 1
exit /b %RESULT%
