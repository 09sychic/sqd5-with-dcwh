# Local Runner for SQD5-DCWH v2.4.1
# Optimized for Discord diagnostics

$ScriptPath = Join-Path $PSScriptRoot "sqd5dcwh.ps1"

if (Test-Path $ScriptPath) {
    Write-Host "[*] Initiating Audit Flow..." -ForegroundColor Cyan
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath
} else {
    Write-Error "Core script missing: $ScriptPath"
}
