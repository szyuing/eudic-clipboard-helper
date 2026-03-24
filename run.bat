@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SCRIPT=%SCRIPT_DIR%EudicClipboardHelper.ahk"
set "AHK_EXE="

if not exist "%SCRIPT%" (
  echo [ERROR] Script file not found:
  echo %SCRIPT%
  echo.
  echo Keep EudicClipboardHelper.ahk and run.bat in the same folder.
  pause
  exit /b 1
)

if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK_EXE if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe" set "AHK_EXE=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe" set "AHK_EXE=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\AutoHotkey64.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\AutoHotkey64.exe"
if not defined AHK_EXE if exist "%ProgramFiles%\AutoHotkey\AutoHotkey.exe" set "AHK_EXE=%ProgramFiles%\AutoHotkey\AutoHotkey.exe"

if not defined AHK_EXE (
  for /f "delims=" %%i in ('where AutoHotkey64.exe 2^>nul') do (
    if not defined AHK_EXE set "AHK_EXE=%%i"
  )
)

if not defined AHK_EXE (
  for /f "delims=" %%i in ('where AutoHotkey.exe 2^>nul') do (
    if not defined AHK_EXE set "AHK_EXE=%%i"
  )
)

if not defined AHK_EXE (
  echo [ERROR] AutoHotkey v2 was not found.
  echo Install it from:
  echo https://www.autohotkey.com/
  pause
  exit /b 1
)

start "" "%AHK_EXE%" "%SCRIPT%"
exit /b 0
