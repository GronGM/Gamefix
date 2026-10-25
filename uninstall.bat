@echo off
:: GameFix - polnoe udalenie sluzhby (papku potom mozhno prosto steret)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0gamefix.ps1\" -Action uninstall -Pause'"
