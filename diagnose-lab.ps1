[CmdletBinding()]
param()
$ErrorActionPreference = 'Continue'
$Root = $PSScriptRoot
$WazuhSingle = Join-Path $Root 'vendor\wazuh-docker\single-node'
$Output = Join-Path $Root ("lab-diagnostics-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (-not (Test-Path $WazuhSingle)) { throw 'Wazuh vendor stack was not found. Run start-lab.ps1 first.' }
$env:LAB_ROOT = $Root
Push-Location $WazuhSingle
try {
  $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
  & {
    '=== Docker resources ==='
    docker stats --no-stream
    '=== Service state ==='
    docker compose @ComposeArgs ps
    '=== Container exit / OOM state ==='
    docker compose @ComposeArgs ps -q | ForEach-Object { docker inspect --format '{{.Name}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{.State.Error}}' $_ }
    '=== Wazuh manager logs (last 250 lines) ==='
    docker compose @ComposeArgs logs --tail=250 wazuh.manager
    '=== Linux victim logs (last 150 lines) ==='
    docker compose @ComposeArgs logs --tail=150 linux-victim
    '=== Suricata logs (last 150 lines) ==='
    docker compose @ComposeArgs logs --tail=150 suricata
    '=== Manager WDB socket ==='
    docker compose @ComposeArgs exec -T wazuh.manager sh -c 'ls -la /var/ossec/queue/db 2>&1; test -S /var/ossec/queue/db/wdb && echo WDB_READY || echo WDB_NOT_READY'
    '=== Victim agent service status ==='
    docker compose @ComposeArgs exec -T linux-victim /var/ossec/bin/wazuh-control status
  } | Tee-Object -FilePath $Output
  Write-Host "Diagnostics saved to $Output" -ForegroundColor Yellow
}
finally { Pop-Location }
