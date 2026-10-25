@echo off
:: GameFix - okno s knopkoy vkl/vykl (zaprosit prava administratora)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -WindowStyle Hidden -ArgumentList '-NoProfile -ExecutionPolicy Bypass -STA -File \"%~dp0GameFix-ui.ps1\"'"
