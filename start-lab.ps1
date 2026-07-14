[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$SkipHealthCheck
)

$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------

$Root = $PSScriptRoot

$WazuhVersion = 'v4.14.6'

$WazuhRoot = Join-Path $Root 'vendor\wazuh-docker'
$WazuhSingle = Join-Path $WazuhRoot 'single-node'

$ComposeFile = Join-Path $WazuhSingle 'docker-compose.yml'

$env:LAB_ROOT = $Root

# --------------------------------------------------------------------
# Helper Functions
# --------------------------------------------------------------------

function Write-Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "===================================================" -ForegroundColor DarkCyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor DarkCyan
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Ensure-WazuhRepository {

    if (Test-Path $ComposeFile) {

        try {
            $remote = git -C $WazuhRoot remote get-url origin 2>$null

            if ($remote -match 'github\.com[:/]+wazuh/wazuh-docker') {
                Write-Host "Using existing Wazuh repository." -ForegroundColor Green
                return
            }

            Write-Warning "Unexpected Git remote detected:"
            Write-Host $remote

        }
        catch {
            Write-Warning "Unable to verify Git repository."
        }

        Write-Warning "Removing invalid Wazuh repository..."

        Remove-Item $WazuhRoot -Recurse -Force
    }

    Write-Step "Downloading Wazuh Docker $WazuhVersion"

    git clone `
        --depth 1 `
        --branch $WazuhVersion `
        https://github.com/wazuh/wazuh-docker.git `
        $WazuhRoot

    if (-not (Test-Path $ComposeFile)) {
        throw "Failed to download Wazuh Docker."
    }
}

function Generate-Certificates {

    Push-Location $WazuhSingle

    try {

        $RootCA = Join-Path $WazuhSingle 'config\wazuh_indexer_ssl_certs\root-ca.pem'

        if (!(Test-Path $RootCA)) {

            Write-Step "Generating Indexer Certificates"

            docker compose `
                -f generate-indexer-certs.yml `
                run `
                --rm `
                generator
        }
        else {

            Write-Host "Certificates already exist." -ForegroundColor Green

        }

    }
    finally {

        Pop-Location

    }

}

function Enable-RawLogArchiving {
    # The upstream single-node example only retains alerts. Preserve its
    # version-pinned configuration and enable JSON archives before the manager
    # starts so Filebeat can index non-alerting events for Discovery.
    $ManagerConfig = Join-Path $WazuhSingle 'config\wazuh_cluster\wazuh_manager.conf'
    $Content = Get-Content -LiteralPath $ManagerConfig -Raw

    if ($Content -notmatch '<logall_json>yes</logall_json>') {
        $Updated = $Content -replace '<logall_json>no</logall_json>', '<logall_json>yes</logall_json>'
        if ($Updated -eq $Content) {
            throw "Unable to enable raw-log archiving in $ManagerConfig"
        }
        [System.IO.File]::WriteAllText(
            $ManagerConfig,
            $Updated,
            (New-Object System.Text.UTF8Encoding($false))
        )
        Write-Host 'Enabled Wazuh JSON raw-event archives.' -ForegroundColor Green
    }
}

function Start-Wazuh {

    Push-Location $WazuhSingle

    try {

        $ComposeArgs = @(
            '-f','docker-compose.yml',
            '-f',(Join-Path $Root 'compose.yml')
        )

        Write-Step "Validating Docker Compose"

        docker compose @ComposeArgs config --quiet

        if (-not $SkipBuild) {

            Write-Step "Building Custom Images"

            docker compose @ComposeArgs build `
                kali `
                linux-victim `
                ubuntu-victim

        }

        Write-Step "Starting Purple Team Lab"

        docker compose @ComposeArgs up -d

    }
    finally {

        Pop-Location

    }

}

function Enable-RawLogIndexing {
    Push-Location $WazuhSingle

    try {
        $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
        $ModuleConfig = docker compose @ComposeArgs exec -T wazuh.manager cat /etc/filebeat/filebeat.yml | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to read the Wazuh Filebeat configuration.'
        }

        if ($ModuleConfig -match '(?ms)archives:\s*\r?\n\s*enabled:\s*true') {
            Write-Host 'Wazuh raw-event archive indexing is already enabled.' -ForegroundColor Green
            return
        }

        # Filebeat's bootstrap process writes indexer credentials to this
        # volume. Update only the archives module after that process completes.
        docker compose @ComposeArgs exec -T wazuh.manager sh -c "sed -i '/^[[:space:]]*archives:/,/^[[:space:]]*enabled:/ s/enabled: false/enabled: true/' /etc/filebeat/filebeat.yml"
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to enable the Wazuh Filebeat archives module.'
        }

        docker compose @ComposeArgs restart wazuh.manager
        if ($LASTEXITCODE -ne 0) {
            throw 'Wazuh manager restart failed after enabling raw-log indexing.'
        }
        Write-Host 'Enabled Wazuh raw-event archive indexing.' -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

function Reconcile-VictimAgents {
    # Recreated lab containers have fresh agent keys. Remove only stale,
    # disconnected records for the two project-owned victims so Wazuh can
    # enroll their replacement containers without a duplicate-name loop.
    Push-Location $WazuhSingle

    try {
        $ComposeArgs = @('-f','docker-compose.yml','-f',(Join-Path $Root 'compose.yml'))
        $Disconnected = docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/agent_control -ln | Out-String
        $Matches = [regex]::Matches($Disconnected, 'ID:\s*(\d+),\s*Name:\s*(linux-victim|ubuntu-victim),')
        $VictimsToRestart = @()

        foreach ($Match in $Matches) {
            $Id = $Match.Groups[1].Value
            $Name = $Match.Groups[2].Value
            docker compose @ComposeArgs exec -T wazuh.manager /var/ossec/bin/manage_agents -r $Id | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to remove stale Wazuh agent '$Name' (ID $Id)."
            }
            $VictimsToRestart += $Name
        }

        if ($VictimsToRestart.Count -gt 0) {
            docker compose @ComposeArgs restart @VictimsToRestart
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to restart victim containers after clearing stale agent registrations.'
            }
            Write-Host "Cleared stale Wazuh registrations for: $($VictimsToRestart -join ', ')." -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}

function Wait-Wazuh {

    Push-Location $WazuhSingle

    try {

        $ComposeArgs = @(
            '-f','docker-compose.yml',
            '-f',(Join-Path $Root 'compose.yml')
        )

        Write-Step "Waiting for Wazuh Manager"

        $Ready = $false

        for ($i=1; $i -le 60; $i++) {

            try {

                docker compose @ComposeArgs exec -T wazuh.manager `
                    /var/ossec/bin/agent_control -l *> $null

                if ($LASTEXITCODE -eq 0) {

                    $Ready = $true
                    break

                }

            }
            catch {
            }

            Write-Host "Attempt $i/60..."

            Start-Sleep 10

        }

        if (-not $Ready) {
            throw "Wazuh Manager failed to initialize."
        }

        Write-Host "Wazuh Manager is ready." -ForegroundColor Green

    }
    finally {

        Pop-Location

    }

}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

Require-Command docker
Require-Command git

docker version --format '{{.Server.Version}}' | Out-Null

Ensure-WazuhRepository

Generate-Certificates

Enable-RawLogArchiving

Start-Wazuh

Enable-RawLogIndexing

Reconcile-VictimAgents

if (-not $SkipHealthCheck) {

    Wait-Wazuh

    Write-Step "Running Lab Validation"

    & (Join-Path $Root 'test-lab.ps1')

}

Write-Host ""
Write-Host "Purple Team Lab is ready." -ForegroundColor Green
