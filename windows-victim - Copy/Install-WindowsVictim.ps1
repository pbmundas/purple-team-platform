# Run in an elevated PowerShell session on a dedicated Windows VM, never on the host.
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string]$WazuhManagerIp,
  [int]$ManagerPort = 15140,
  [int]$RegistrationPort = 15150,
  [string]$AgentMsiUrl = 'https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.6-1.msi'
)
$ErrorActionPreference = 'Stop'
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script as Administrator.' }
$msi = Join-Path $env:TEMP 'wazuh-agent.msi'
Invoke-WebRequest -Uri $AgentMsiUrl -OutFile $msi
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /q WAZUH_MANAGER=$WazuhManagerIp WAZUH_MANAGER_PORT=$ManagerPort WAZUH_REGISTRATION_SERVER=$WazuhManagerIp WAZUH_REGISTRATION_PORT=$RegistrationPort WAZUH_AGENT_NAME=windows-victim"
# Sysmon provides high-value process/network telemetry for Wazuh. Download it only from Microsoft Sysinternals.
Write-Host "Wazuh agent installed. Allow TCP $ManagerPort and $RegistrationPort from this VM to $WazuhManagerIp, then verify it appears in the dashboard."
