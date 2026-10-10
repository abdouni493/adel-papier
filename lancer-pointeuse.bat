@echo off
title Passerelle pointeuse ZKTeco - Adel Papier
cd /d "%~dp0"
:loop
node pointeuse\bridge.mjs
echo La passerelle s'est arretee - redemarrage dans 10 secondes...
timeout /t 10 /nobreak >nul
goto loop
