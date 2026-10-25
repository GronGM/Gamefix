@echo off
:: GameFix - obnovit spisok mertvyh IP (esli Discord/igra vdrug perestali zahodit, a status.bat pokazyvaet, chto vse rabotaet)
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0gamefix.ps1\" -Action deadips -Pause'"
