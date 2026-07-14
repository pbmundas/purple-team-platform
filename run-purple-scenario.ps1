[CmdletBinding()]
param(
  [ValidateSet('Reconnaissance', 'WebProbe')]
  [string]$Scenario = 'Reconnaissance'
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$WazuhSingle = Join-Path $Root 'vendor\wazuh-docker\single-node'
$env:LAB_ROOT = $Root
$scriptName = switch ($Scenario) {
  'Reconnaissance' { '01-reconnaissance.sh' }
  'WebProbe' { '02-web-probe.sh' }
}

Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f', 'docker-compose.yml', '-f', (Join-Path $Root 'compose.yml'))
  $kali = docker compose @ComposeArgs ps -q kali
  $victim = docker compose @ComposeArgs ps -q linux-victim
  if (-not $kali -or -not $victim) { throw 'Kali or linux-victim is not running. Run .\start-lab.ps1 first.' }

  Write-Host "Running $Scenario from Kali against the isolated linux-victim..." -ForegroundColor Cyan
  docker compose @ComposeArgs exec -T kali sh "/opt/purple/scenarios/$scriptName"
  if ($LASTEXITCODE -ne 0) { throw "$Scenario failed." }

  Write-Host "Completed. In Wazuh, set the time range to Last 15 minutes and open Purple Lab - Threat Detection." -ForegroundColor Green
  if ($Scenario -eq 'WebProbe') {
    Write-Host 'Filter rule.groups: purple_team and rule.groups: web_probe to find the tagged HTTP event.' -ForegroundColor Green
  }
}
finally { Pop-Location }
