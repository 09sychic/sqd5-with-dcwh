# Local Runner for SQD5-DCWH
# This script runs the local version of the WiFi password extractor

$ScriptPath = Join-Path $PSScriptRoot "sqd5dcwh.ps1"

if (Test-Path $ScriptPath) {
    Write-Host "[*] Starting local execution..." -ForegroundColor Cyan
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
} else {
    Write-Error "Main script not found at $ScriptPath"
}
