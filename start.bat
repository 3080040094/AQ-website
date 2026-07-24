@echo off
chcp 65001 >nul 2>&1
title AQ Website Server v1.9.0
echo.
echo Starting AQ Website Server...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1"
echo.
echo Server has stopped. Press any key to close.
pause >nul
