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
  $expected = @('wazuh.manager','wazuh.indexer','wazuh.dashboard','kali','linux-victim','ubuntu-victim','suricata','caldera')
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
  $connected = $false
  do {
    $agent = docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/agent_control -l 2>$null | Out-String
    $connected = $LASTEXITCODE -eq 0
    foreach ($name in @('linux-victim', 'ubuntu-victim')) {
      $connected = $connected -and $agent -match "Name: $name.*Active"
    }
    if (-not $connected) { Start-Sleep -Seconds 5 }
  } while (-not $connected -and (Get-Date) -lt $deadline)
  if (-not $connected) { throw 'Wazuh manager is ready, but one or more victim agents did not connect before timeout.' }
  $policyLoaded = $false
  do {
    $policyLoaded = $true
    foreach ($name in @('linux-victim', 'ubuntu-victim')) {
      docker compose @ComposeArgs exec -T $name sh -c "grep -F '/var/log/purple/auth.log' /var/ossec/etc/shared/merged.mg >/dev/null 2>&1"
      if ($LASTEXITCODE -ne 0) { $policyLoaded = $false; break }
    }
    if (-not $policyLoaded) { Start-Sleep -Seconds 5 }
  } while (-not $policyLoaded -and (Get-Date) -lt $deadline)
  if (-not $policyLoaded) { throw 'Victim agents connected, but the central Wazuh log-collection policy was not applied before timeout.' }
  $marker = "purple-team-wazuh-test-$([guid]::NewGuid().ToString('N'))"
  foreach ($name in @('linux-victim', 'ubuntu-victim')) {
    docker compose @ComposeArgs exec -T $name sh -c "echo $marker-$name >> /var/log/purple/auth.log"
  }
  $delivered = $false
  for ($attempt = 0; $attempt -lt 12; $attempt++) {
    $alerts = docker compose @ComposeArgs exec -T wazuh.manager sh -c "grep -F '$marker-linux-victim' /var/ossec/logs/alerts/alerts.json 2>/dev/null; grep -F '$marker-ubuntu-victim' /var/ossec/logs/alerts/alerts.json 2>/dev/null" | Out-String
    $archives = docker compose @ComposeArgs exec -T wazuh.manager sh -c "grep -F '$marker-linux-victim' /var/ossec/logs/archives/archives.json 2>/dev/null; grep -F '$marker-ubuntu-victim' /var/ossec/logs/archives/archives.json 2>/dev/null" | Out-String
    if (
      $alerts -match [regex]::Escape("$marker-linux-victim") -and
      $alerts -match [regex]::Escape("$marker-ubuntu-victim") -and
      $archives -match [regex]::Escape("$marker-linux-victim") -and
      $archives -match [regex]::Escape("$marker-ubuntu-victim")
    ) { $delivered = $true; break }
    Start-Sleep -Seconds 5
  }
  if (-not $delivered) { throw 'Agents are connected, but Wazuh did not record both delivery-test logs as alerts and raw archives.' }
  docker compose @ComposeArgs exec -T kali nmap -sV linux-victim
  Write-Host 'PASS: all containers are running, both victims are connected, and Wazuh recorded alert and raw-log evidence from each agent.' -ForegroundColor Green
}
finally { Pop-Location }
