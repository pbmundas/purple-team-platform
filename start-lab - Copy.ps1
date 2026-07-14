[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipHealthCheck
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$WazuhVersion = 'v4.14.6'
$WazuhRoot = Join-Path $Root 'vendor\wazuh-docker'
$WazuhSingle = Join-Path $WazuhRoot 'single-node'
$env:LAB_ROOT = $Root

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { throw "Required command not found: $Name" }
}
Require-Command docker
Require-Command git

docker version --format '{{.Server.Version}}' | Out-Null
if (-not (Test-Path $WazuhRoot)) {
    Write-Host "Downloading pinned Wazuh Docker stack $WazuhVersion..."
    git clone --depth 1 --branch $WazuhVersion https://github.com/wazuh/wazuh-docker.git $WazuhRoot
}

Push-Location $WazuhSingle
try {
    # Official Wazuh stack needs indexer TLS certificates before the first boot.
    if (-not (Test-Path '.\config\wazuh_indexer_ssl_certs\root-ca.pem')) {
        docker compose -f generate-indexer-certs.yml run --rm generator
    }
    $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
    docker compose @ComposeArgs config --quiet
    if (-not $SkipBuild) { docker compose @ComposeArgs build kali linux-victim }
    docker compose @ComposeArgs up -d
    if (-not $SkipHealthCheck) { & (Join-Path $Root 'test-lab.ps1') }
}
finally { Pop-Location }
