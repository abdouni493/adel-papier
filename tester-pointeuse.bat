@echo off
title Test pointeuse - Adel Papier
cd /d "%~dp0"
echo === IP du PC ===
ipconfig | findstr /C:"Carte" /C:"IPv4"
echo.
echo === Ping pointeuse 192.168.1.201 ===
ping -n 2 192.168.1.201
echo.
echo === Passerelle (port 8090) ===
netstat -ano | findstr ":8090" | findstr "LISTENING" >nul && (echo Passerelle en marche.) || (echo [!] Passerelle arretee : lancez lancer-pointeuse.bat)
echo.
echo === Pare-feu ===
netsh advfirewall firewall show rule name="Pointeuse ZKTeco 8090" | findstr /C:"Activ" /C:"Enabled"
echo.
echo === Dernieres lignes du journal de la passerelle ===
powershell -NoProfile -Command "if (Test-Path 'pointeuse\bridge.log') { Get-Content 'pointeuse\bridge.log' -Tail 15 } else { 'Pas encore de journal.' }"
echo.
start "" http://localhost:8090
pause
