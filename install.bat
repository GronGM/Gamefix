@echo off
:: GameFix - ustanovka (zaprosit prava administratora)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0gamefix.ps1\" -Action install -Pause'"
