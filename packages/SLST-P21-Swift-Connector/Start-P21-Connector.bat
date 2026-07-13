@echo off
title SLST P21 Connector
cd /d "%~dp0"

if not exist ".env" (
  if exist ".env.example" copy /Y ".env.example" ".env" >nul
  echo Created .env — edit P21_USERNAME and P21_PASSWORD, save, then run again.
  notepad ".env"
  pause
  exit /b 1
)

findstr /I /C:"your.p21.username" ".env" >nul
if not errorlevel 1 (
  echo .env still has placeholder username. Edit .env first.
  notepad ".env"
  pause
  exit /b 1
)

echo Starting P21 proxy — leave this window open.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-proxy.ps1"
pause
