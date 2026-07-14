# Docker Purple Team Lab (Windows host)

This package creates an isolated, Linux-container lab containing:

- **Kali** attack workstation with Nmap, Netcat, PowerShell, and the Atomic Red Team library.
- **MITRE CALDERA** on port `8888` for controlled adversary emulation.
- **Wazuh manager, indexer, and dashboard** from Wazuh's pinned official `v4.14.6` Compose stack. Dashboard: `https://localhost` (default `admin` / `SecretPassword`).
- **Linux victim** protected by a Wazuh agent.
- **Suricata**, sharing the victim network namespace to inspect traffic to that victim. Its EVE JSON is sent to Wazuh by the victim agent.

## Prerequisites

Docker Desktop must be in **Linux containers** mode, use the WSL 2 engine, and be allocated at least **4 CPUs, 8 GB RAM, and 40 GB disk**. Internet access is required on first run to fetch upstream images and the pinned Wazuh source. This lab intentionally does not expose the victim or Kali onto host ports.

The manager's standard container ports are published to host ports `15140` (agent traffic), `15150` (enrollment), `5514/UDP` (syslog), and `55000` (API). Override any of them before launch, for example: `$env:WAZUH_AGENT_PORT = '2514'`. This avoids conflicts with existing local Wazuh installations using port 1514.

Run PowerShell from this folder:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\start-lab.ps1
```

First launch can take 15–30 minutes. Browse to Wazuh at `https://localhost` and CALDERA at `http://localhost:8888`. CALDERA generates credentials on first start; retrieve them with `docker logs purple-caldera`. The CALDERA image uses MITRE's published `latest` tag; override it before launch with `$env:CALDERA_IMAGE = 'ghcr.io/mitre/caldera:latest'` only if you maintain a tested mirror/tag.

## Validate and exercise

`start-lab.ps1` runs configuration validation, builds the custom images, starts every service, waits for the `linux-victim` agent, and performs a safe Nmap service-discovery check. To rerun the checks:

```powershell
.\test-lab.ps1
```

If `linux-victim` appears as **Disconnected**, remove its stale **linux-victim** record in Wazuh Agents, then run `./repair-linux-victim.ps1`. It recreates the agent with Wazuh's supported startup registration, persists the enrollment key, and reapplies the centralized Suricata log policy. For an external Ubuntu VM, follow `ubuntu-victim/Reconnect-UbuntuVictim.md`.

If the manager repeatedly reports `queue/db/wdb` missing after ten minutes, run `./diagnose-lab.ps1` and inspect the saved diagnostics file. Check especially for `oom=true`, a non-zero manager exit code, or Wazuh configuration errors.

Run only authorized exercises against the lab victim:

```powershell
docker exec purple-kali nmap -sV linux-victim
docker exec purple-kali sh -c 'for p in 80 22 443; do nc -zv linux-victim $p; done'
```

In Wazuh Discover, use `data.location:/var/log/suricata/eve.json` for network telemetry, `rule.groups:purple_team` for the included custom alerts, and the built-in Security Events / MITRE ATT&CK views for dashboards and alert triage.

## Windows victim

Docker Desktop's Linux engine cannot provide a faithful Windows victim with Windows event logs or Sysmon. Create an isolated Windows VM (Hyper-V is suitable) on a host-only/isolated network, expose the Wazuh manager ports to that VM as needed, and run `windows-victim\Install-WindowsVictim.ps1` from an elevated session. Do **not** run attack simulations against the Windows host.

## Stop and reset

```powershell
.\stop-lab.ps1
```

For a complete reset, run `docker compose down -v` from `vendor\wazuh-docker\single-node` with both Compose files, then remove `vendor\wazuh-docker`. This erases Wazuh and CALDERA data.

## Safety

Keep this stack on Docker's private bridge network. Use only systems and attacks you explicitly own or are authorized to test. Do not publish Wazuh, CALDERA, manager, or agent ports to untrusted networks.
