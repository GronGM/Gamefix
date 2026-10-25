@echo off
:: GameFix - sostoyanie i proverka (bez prav administratora)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gamefix.ps1" -Action test -Pause
