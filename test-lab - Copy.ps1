[CmdletBinding()]
param([int]$TimeoutSeconds = 360)
$ErrorActionPreference = 'Stop'
$WazuhSingle = Join-Path $PSScriptRoot 'vendor\wazuh-docker\single-node'
$Override = Join-Path $PSScriptRoot 'compose.yml'
$env:LAB_ROOT = $PSScriptRoot
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f','docker-compose.yml','-f',$Override)
  $expected = @('wazuh.manager','wazuh.indexer','wazuh.dashboard','kali','linux-victim','suricata','caldera')
  do {
    $state = @(docker compose @ComposeArgs ps --format json | ConvertFrom-Json)
    $bad = $expected | Where-Object {
      $entry = $state | Where-Object Service -eq $_ | Select-Object -First 1
      -not $entry -or $entry.State -ne 'running'
    }
    # Do not call agent_control until manager Wazuh DB has been created. Its
    # startup stderr otherwise becomes terminating in some PowerShell builds.
    if (-not $bad) {
      $wdbCheck = docker compose @ComposeArgs exec -T wazuh.manager sh -c 'test -S /var/ossec/queue/db/wdb' 2>$null
      if ($LASTEXITCODE -eq 0) { break }
    }
    Start-Sleep -Seconds 10
  } while ((Get-Date) -lt $deadline)
  if ($bad) {
    docker compose @ComposeArgs ps
    docker compose @ComposeArgs logs --tail=80 wazuh.manager
    throw "Services not running: $($bad -join ', ')"
  }
  $agent = docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/agent_control -l 2>$null | Out-String
  if ($LASTEXITCODE -ne 0 -or $agent -notmatch 'linux-victim') { throw 'Wazuh manager is ready, but linux-victim did not enroll before timeout.' }
  docker compose @ComposeArgs exec -T kali nmap -sV linux-victim
  Write-Host 'PASS: all containers are running and the Linux victim enrolled in Wazuh.' -ForegroundColor Green
}
finally { Pop-Location }
