# For users who extracted the original package: apply the CALDERA image fix
# without re-extracting the updated ZIP, then rerun start-lab.ps1.
$ErrorActionPreference = 'Stop'
$compose = Join-Path $PSScriptRoot 'compose.yml'
if (-not (Test-Path $compose)) { throw "compose.yml was not found beside this script." }
$content = Get-Content -Raw $compose
$old = 'image: ghcr.io/mitre/caldera:5.3.0'
$new = 'image: ${CALDERA_IMAGE:-ghcr.io/mitre/caldera:latest}'
if ($content.Contains($old)) {
  Set-Content -LiteralPath $compose -Value $content.Replace($old, $new) -NoNewline
  Write-Host 'Updated CALDERA image reference. Run .\start-lab.ps1 again.' -ForegroundColor Green
} elseif ($content.Contains('ghcr.io/mitre/caldera:latest')) {
  Write-Host 'CALDERA image reference is already fixed.' -ForegroundColor Yellow
} else { throw 'Expected CALDERA image reference was not found; do not modify automatically.' }
