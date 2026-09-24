@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-backend-to-xampp.ps1" %*
if errorlevel 1 exit /b 1
