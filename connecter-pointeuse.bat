@echo off
title Connexion pointeuse (cable direct) - Adel Papier
cd /d "%~dp0"

rem --- Relance automatique en administrateur ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Demande des droits administrateur...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\connecter-pointeuse.ps1"
echo.
pause
