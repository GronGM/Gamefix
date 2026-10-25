@echo off
:: GameFix - zanovo podobrat strategiyu (esli smenil provaydera ili perestalo rabotat)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0gamefix.ps1\" -Action retest -Pause'"
