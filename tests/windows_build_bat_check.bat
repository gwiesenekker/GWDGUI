@echo off
rem Regression check for build.bat (review C12); run it on Windows:
rem   tests\windows_build_bat_check.bat
rem It runs a copy of build.bat in lib\build-bat-check with a stand-in for
rem lazbuild that succeeds, fails, fails after writing a partial executable, or
rem succeeds without output, and checks that the last good gwdgui.exe is never
rem lost: after every run gwdgui.exe holds the new build or the previous one.
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "WORK=%ROOT%\lib\build-bat-check"
if exist "%WORK%" rd /s /q "%WORK%"
if not exist "%ROOT%\lib" mkdir "%ROOT%\lib"
set "FAILURES=0"
mkdir "%WORK%"
if not exist "%WORK%\" exit /b 1
copy /y "%ROOT%\build.bat" "%WORK%\build.bat" >nul
if not exist "%WORK%\build.bat" exit /b 1
type nul > "%WORK%\gwdgui.lpi"
type nul > "%WORK%\draughts.ttf"
set "FAKE=%WORK%\fake_lazbuild.cmd"
echo @echo off> "%FAKE%"
echo if "%%FAKE_MODE%%"=="ok" echo NEW^> "%%GWDGUI_BUILD_DIR%%gwdgui.exe">> "%FAKE%"
echo if "%%FAKE_MODE%%"=="partial" echo PARTIAL^> "%%GWDGUI_BUILD_DIR%%gwdgui.exe">> "%FAKE%"
echo if "%%FAKE_MODE%%"=="ok" exit /b 0>> "%FAKE%"
echo if "%%FAKE_MODE%%"=="nooutput" exit /b 0>> "%FAKE%"
rem Redirection first: "echo exit /b 2>>" would redirect stderr.
>> "%FAKE%" echo exit /b 2

rem            name              lazbuild  gwdgui.exe  .old.exe  expected exe  expected .old  exit
call :scenario success           ok        OLD         -         NEW           -              0
call :scenario failure           fail      OLD         -         OLD           -              nonzero
call :scenario partial-output    partial   OLD         -         OLD           -              nonzero
call :scenario no-output         nooutput  OLD         -         OLD           -              nonzero
call :scenario first-build       ok        -           -         NEW           -              0
call :scenario first-failure     fail      -           -         -             -              nonzero
call :scenario interrupted-fail  fail      -           OLD       OLD           -              nonzero
call :scenario interrupted-ok    ok        -           OLD       NEW           -              0
call :scenario leftover-backup   ok        GOOD        OLDER     NEW           -              0
call :scenario leftover-failure  fail      GOOD        OLDER     GOOD          OLDER          nonzero
rem A failed build followed by a retry keeps the original executable.
call :scenario retry-1           partial   OLD         -         OLD           -              nonzero
call :scenario retry-2           partial   keep        keep      OLD           -              nonzero

rd /s /q "%WORK%"
if not "%FAILURES%"=="0" (
  echo %FAILURES% build.bat checks failed
  exit /b 1
)
echo build.bat checks passed
exit /b 0

:scenario
if not "%~3"=="keep" (
  if exist "%WORK%\gwdgui.exe" del /f /q "%WORK%\gwdgui.exe"
  if not "%~3"=="-" echo %~3> "%WORK%\gwdgui.exe"
)
if not "%~4"=="keep" (
  if exist "%WORK%\gwdgui.old.exe" del /f /q "%WORK%\gwdgui.old.exe"
  if not "%~4"=="-" echo %~4> "%WORK%\gwdgui.old.exe"
)
set "FAKE_MODE=%~2"
call "%WORK%\build.bat" "%FAKE%" > "%WORK%\%~1.log" 2>&1
set "RC=%ERRORLEVEL%"
call :content gwdgui.exe
set "EXE=%CONTENT%"
call :content gwdgui.old.exe
set "OLD=%CONTENT%"
set "OK=1"
if not "%EXE%"=="%~5" set "OK="
if not "%OLD%"=="%~6" set "OK="
if "%~7"=="0" if not "%RC%"=="0" set "OK="
if "%~7"=="nonzero" if "%RC%"=="0" set "OK="
if defined OK (
  echo ok   %~1
) else (
  echo FAIL %~1: gwdgui.exe=%EXE% gwdgui.old.exe=%OLD% exit=%RC%; expected %~5, %~6, %~7
  type "%WORK%\%~1.log"
  set /a FAILURES+=1
)
exit /b 0

:content
set "CONTENT=-"
if exist "%WORK%\%~1" set /p CONTENT=<"%WORK%\%~1"
exit /b 0
