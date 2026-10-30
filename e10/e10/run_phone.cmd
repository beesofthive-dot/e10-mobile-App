@echo off
setlocal
cd /d "%~dp0"
echo START %DATE% %TIME% > "%TEMP%\e10-flutter-phone.log"
call flutter run -d 111395541T002959 >> "%TEMP%\e10-flutter-phone.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%TEMP%\e10-flutter-phone.log"
