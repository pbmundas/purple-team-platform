[CmdletBinding()]
param(
  [string]$DashboardUser = $env:WAZUH_DASHBOARD_USER,
  [string]$DashboardPassword = $env:WAZUH_DASHBOARD_PASSWORD
)

$ErrorActionPreference = 'Stop'
if (-not $DashboardUser) { $DashboardUser = 'admin' }
if (-not $DashboardPassword) { $DashboardPassword = 'SecretPassword' }
$Root = $PSScriptRoot
$WazuhSingle = Join-Path $Root 'vendor\wazuh-docker\single-node'
$Bundle = Join-Path $Root 'dashboards\threat-hunting.ndjson'
$env:LAB_ROOT = $Root

Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
  $Manager = docker compose @ComposeArgs ps -q wazuh.manager
  if (-not $Manager) { throw 'Wazuh manager is not running. Start the lab first.' }
  docker cp $Bundle "${Manager}:/tmp/threat-hunting.ndjson"
  $result = docker exec $Manager sh -c "curl -ksS -u '$DashboardUser`:$DashboardPassword' -H 'osd-xsrf: true' --form file=@/tmp/threat-hunting.ndjson 'https://wazuh.dashboard:5601/api/saved_objects/_import?overwrite=true'"
  $import = $result | ConvertFrom-Json
  if (-not $import.success) { throw "Dashboard import failed: $result" }
  Write-Host 'Installed: Purple Lab - Threat Detection and Purple Lab - Threat Investigation.' -ForegroundColor Green
}
finally { Pop-Location }
