@echo off
cd /d "%~dp0"
echo START %DATE% %TIME% > "%TEMP%\e10-flutter-chrome.log"
call flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8081 >> "%TEMP%\e10-flutter-chrome.log" 2>&1
echo EXIT=%ERRORLEVEL% >> "%TEMP%\e10-flutter-chrome.log"
