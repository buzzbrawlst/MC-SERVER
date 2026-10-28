@echo off
setlocal
title MC-SERVER Launcher
cd /d "%~dp0"
echo.
echo  ==========================================
echo           MC-SERVER Network Launcher
echo  ==========================================
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start-Network.ps1"
if errorlevel 1 (
  echo.
  echo MC-SERVER could not start. Read the message above.
  pause
)
endlocal
