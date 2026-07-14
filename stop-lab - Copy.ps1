$ErrorActionPreference = 'Stop'
$env:LAB_ROOT = $PSScriptRoot
$WazuhSingle = Join-Path $PSScriptRoot 'vendor\wazuh-docker\single-node'
if (Test-Path $WazuhSingle) {
  Push-Location $WazuhSingle
  try { docker compose -f docker-compose.yml -f (Join-Path $PSScriptRoot 'compose.yml') down }
  finally { Pop-Location }
}
