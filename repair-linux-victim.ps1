[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$WazuhSingle = Join-Path $Root 'vendor\wazuh-docker\single-node'
if (-not (Test-Path $WazuhSingle)) { throw 'The Wazuh stack has not been initialized. Run .\start-lab.ps1 first.' }
$env:LAB_ROOT = $Root
Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
  $agents = docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/agent_control -l 2>$null | Out-String
  if ($agents -match 'ID: (\d+), Name: linux-victim.*Disconnected') {
    docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/manage_agents -r $Matches[1]
  }
  docker compose @ComposeArgs up -d --build --force-recreate linux-victim
  Write-Host 'Linux victim recreated with Wazuh auto-registration enabled.' -ForegroundColor Green
  & (Join-Path $Root 'test-lab.ps1') -TimeoutSeconds 600
}
finally { Pop-Location }
