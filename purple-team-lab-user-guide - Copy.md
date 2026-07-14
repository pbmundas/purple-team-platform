# Purple Team Lab — User Guide

This guide covers the Docker-based purple-team lab: Kali Linux, MITRE CALDERA, Wazuh, a monitored Linux victim, and Suricata network monitoring. Use it only on systems and networks you own or are explicitly authorized to test.

## 1. What is deployed

| Component | Purpose | Access |
|---|---|---|
| Wazuh manager, indexer, dashboard | SIEM, alerting, agent management, dashboards | `https://localhost` |
| Kali | Isolated attacker workstation | `docker exec purple-kali sh` |
| Linux victim | Wazuh-monitored target | Internal Docker network only |
| Suricata | Inspects traffic to the Linux victim; writes EVE JSON | Data appears in Wazuh |
| MITRE CALDERA | Adversary-emulation platform | `http://localhost:8888` |

Wazuh default login: `admin` / `SecretPassword`. CALDERA creates credentials at first start; see them with `docker logs purple-caldera`.

## 2. Prerequisites

- Windows 10/11 with Docker Desktop configured for **Linux containers** and the **WSL 2 engine**.
- Docker Desktop resource allocation: at least 4 CPUs, 8 GB RAM, and 40 GB free disk.
- PowerShell and Git available in `PATH`.
- Internet access for the first run, when images, the pinned Wazuh stack, and Atomic Red Team are fetched.

The lab maps Wazuh to non-default host ports to avoid a collision with an existing Wazuh agent/service:

| Host port | Container port | Purpose |
|---:|---:|---|
| 15140/TCP | 1514 | Agent events |
| 15150/TCP | 1515 | Agent enrollment |
| 5514/UDP | 514 | Syslog |
| 55000/TCP | 55000 | Wazuh API |

If one is busy, choose another before starting, for example:

```powershell
$env:WAZUH_AGENT_PORT = '2514'
```

## 3. Start the lab

1. Extract the latest lab ZIP to a folder, for example `C:\Labs\purple-team-lab`.
2. Open PowerShell in that folder.
3. Allow scripts only for the current PowerShell process and start:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\start-lab.ps1
```

On the first run, Wazuh certificates are generated, the Wazuh source is downloaded into `vendor\wazuh-docker`, and custom images are built. This can take 15–30 minutes.

The script validates Compose, starts the services, waits for Wazuh to initialize, waits for `linux-victim` to enroll, and performs a safe service-discovery test. Do not interrupt it while Wazuh is creating its database.

## 4. Confirm the lab is healthy

Run the built-in test. Six to ten minutes is normal on a first launch:

```powershell
.\test-lab.ps1 -TimeoutSeconds 600
```

A successful run ends with:

```text
PASS: all containers are running and the Linux victim enrolled in Wazuh.
```

To check container state manually:

```powershell
docker ps --format "table {{.Names}}\t{{.Status}}"
docker logs purple-linux-victim --tail 100
docker logs purple-suricata --tail 100
```

Expected running containers include `purple-kali`, `purple-caldera`, `purple-linux-victim`, `purple-suricata`, and the Wazuh manager/indexer/dashboard containers.

## 5. Run safe lab tests

Only target `linux-victim`, which is isolated on the Docker network.

### Test A: service discovery

```powershell
docker exec purple-kali nmap -sV linux-victim
```

### Test B: limited TCP connection checks

```powershell
docker exec purple-kali sh -c 'for p in 80 22 443; do nc -zv linux-victim $p; done'
```

### Test C: inspect the Atomic Red Team library

```powershell
docker exec purple-kali sh -c 'ls /opt/atomic-red-team/atomics | head'
```

The Atomic Red Team library is included for authorized emulation planning. Do not execute tests against the Windows host, your home network, or any other system without written authorization.

## 6. Review alerts and telemetry in Wazuh

1. Open `https://localhost` and accept the local certificate warning.
2. Sign in with `admin` / `SecretPassword`.
3. Open **Discover**.
4. Use these queries:

```text
data.location:/var/log/suricata/eve.json
```

Shows Suricata JSON telemetry.

```text
rule.groups:purple_team
```

Shows the lab’s custom Suricata and file-integrity detection rules.

```text
agent.name:linux-victim
```

Shows events collected from the Linux victim.

Use Wazuh’s built-in Security Events and MITRE ATT&CK views for broader alert investigation and tactic/technique context.

## 7. Use CALDERA

1. Open `http://localhost:8888`.
2. Get the first-start credentials:

```powershell
docker logs purple-caldera
```

3. Log in, review the built-in training, then create only lab-scoped operations.

CALDERA is an emulation platform; it does not automatically compromise the Linux victim. Review each ability and payload before using it.

## 8. Add a Windows VM victim (optional)

Docker Desktop Linux containers cannot provide a realistic Windows endpoint with Windows Event Logs and Sysmon. Use an isolated Windows VM instead.

1. Ensure the VM can reach the Docker host on TCP 15140 and TCP 15150.
2. From an elevated PowerShell window on the VM, run:

```powershell
.\windows-victim\Install-WindowsVictim.ps1 -WazuhManagerIp '<DOCKER-HOST-IP>'
```

3. Confirm the `windows-victim` agent appears in the Wazuh dashboard.

If you changed the host ports, pass `-ManagerPort` and `-RegistrationPort` with the matching values.

## 9. Troubleshooting

### `Bind for 0.0.0.0:1514 failed: port is already allocated`

Use the updated package, which maps the host to 15140 instead of 1514. Alternatively select another free port before running `start-lab.ps1`:

```powershell
$env:WAZUH_AGENT_PORT = '2514'
.\start-lab.ps1
```

### `agent_control: Cannot find 'queue/db/wdb'`

Wazuh is still starting. Wait and rerun:

```powershell
.\test-lab.ps1 -TimeoutSeconds 600
```

### Dashboard does not load

Check resources and service logs:

```powershell
docker stats --no-stream
docker logs single-node-wazuh.dashboard-1 --tail 100
docker logs single-node-wazuh.indexer-1 --tail 100
```

### Clean restart

```powershell
.\stop-lab.ps1
.\start-lab.ps1
```

## 10. Stop or remove the lab

To stop the lab without deleting data:

```powershell
.\stop-lab.ps1
```

To permanently remove containers, volumes, Wazuh data, and CALDERA data, run this only if you want a clean slate:

```powershell
Set-Location .\vendor\wazuh-docker\single-node
$env:LAB_ROOT = (Resolve-Path ..\..\..).Path
docker compose -f docker-compose.yml -f $env:LAB_ROOT\compose.yml down -v
```

