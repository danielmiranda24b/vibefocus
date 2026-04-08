@echo off
title VibeFocus Installer
echo.
echo   VibeFocus — Installing...
echo.
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/danielmiranda24b/vibefocus/main/viberaise/install.ps1 | iex"
echo.
pause
