@echo off
title Installation passerelle pointeuse - Adel Papier
cd /d "%~dp0"

rem --- Relance automatique en administrateur (necessaire pour le pare-feu) ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Demande des droits administrateur...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo [1/2] Pare-feu : ouverture du port 8090...
netsh advfirewall firewall delete rule name="Pointeuse ZKTeco 8090" >nul 2>&1
netsh advfirewall firewall add rule name="Pointeuse ZKTeco 8090" dir=in action=allow protocol=TCP localport=8090 profile=any
if %errorlevel% neq 0 (
  echo [!] Echec de la regle pare-feu.
) else (
  echo     OK
)

echo [2/2] Demarrage automatique...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-pointeuse-startup.ps1"

echo.
echo Termine. Lancez maintenant lancer-pointeuse.bat
pause
