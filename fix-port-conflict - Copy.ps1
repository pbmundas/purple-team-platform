# Apply the port-conflict fix to an original extracted package, then restart.
$ErrorActionPreference = 'Stop'
$compose = Join-Path $PSScriptRoot 'compose.yml'
$content = Get-Content -Raw $compose
if ($content -match 'ports: !override') { Write-Host 'Port mappings are already fixed.'; exit 0 }
$needle = "    networks: [default, purple-net]"
$replacement = @'
    networks: [default, purple-net]
    ports: !override
      - "${WAZUH_AGENT_PORT:-15140}:1514"
      - "${WAZUH_REGISTRATION_PORT:-15150}:1515"
      - "${WAZUH_SYSLOG_PORT:-5514}:514/udp"
      - "${WAZUH_API_PORT:-55000}:55000"
'@.TrimEnd()
if (-not $content.Contains($needle)) { throw 'Expected Wazuh manager network setting was not found; no change made.' }
Set-Content -LiteralPath $compose -Value $content.Replace($needle, $replacement) -NoNewline
Write-Host 'Updated Wazuh host ports to 15140/15150/5514/55000. Run .\start-lab.ps1 again.' -ForegroundColor Green
