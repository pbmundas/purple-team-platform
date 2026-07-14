[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$WazuhSingle = Join-Path $Root 'vendor\wazuh-docker\single-node'
$env:LAB_ROOT = $Root
$marker = "purple-lab-rehearsal-$([guid]::NewGuid().ToString('N'))"

Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
  docker compose @ComposeArgs exec -T linux-victim sh -c "echo $marker >> /var/log/purple/auth.log"
  $deadline = (Get-Date).AddSeconds(90)
  do {
    $alerts = docker compose @ComposeArgs exec -T wazuh.manager sh -c "grep -F '$marker' /var/ossec/logs/alerts/alerts.json 2>/dev/null" | Out-String
    if ($alerts -match [regex]::Escape($marker)) { break }
    Start-Sleep -Seconds 5
  } while ((Get-Date) -lt $deadline)
  if ($alerts -notmatch [regex]::Escape($marker)) { throw 'The rehearsal event did not reach Wazuh.' }
  Write-Host "PASS: high-severity rehearsal alert received. Open 'Purple Lab - Threat Detection' and set the time range to Last 15 minutes." -ForegroundColor Green
}
finally { Pop-Location }
