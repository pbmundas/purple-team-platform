# Docker Purple Team Lab (Windows Host)

A self-contained **Purple Team Lab** running on Docker Desktop (Linux containers) for safe adversary emulation, detection engineering, and security monitoring.

---

# Architecture

```text
                +---------------------------+
                |      Windows Host         |
                | Docker Desktop (WSL2)     |
                +-------------+-------------+
                              |
                    Docker Bridge Network
                              |
    ------------------------------------------------------------------
    |                |                 |                |              |
+---------+    +-------------+   +------------+   +-------------+   +-----------+
|  Kali   |    |  CALDERA    |   | Linux      |   |  Suricata   |   |  Wazuh    |
| Attacker|--->| Adversary   |-->| Victim     |<--| IDS Sensor  |-->| Manager   |
|         |    | Emulation   |   | + Agent    |   | (same netns)|   | Indexer   |
+---------+    +-------------+   +------------+   +-------------+   | Dashboard |
                                                                     +-----------+
```

---

# Components

The lab includes the following services:

| Component | Purpose |
|----------|----------|
| **Kali Linux** | Attack workstation containing Nmap, Netcat, PowerShell, and the Atomic Red Team library. |
| **MITRE CALDERA** | Controlled adversary emulation platform available on **port 8888**. |
| **Wazuh Manager** | Central security manager receiving endpoint and Suricata telemetry. |
| **Wazuh Indexer** | Stores security events and alerts. |
| **Wazuh Dashboard** | Web UI available at **https://localhost**. |
| **Linux Victim** | Target machine monitored by a Wazuh agent. |
| **Suricata IDS** | Shares the victim's network namespace to inspect network traffic and forward EVE JSON logs to Wazuh. |

---

# Prerequisites

Before starting the lab, ensure Docker Desktop is configured with:

- Linux Containers mode
- WSL2 backend enabled
- Minimum **4 CPUs**
- Minimum **8 GB RAM**
- Minimum **40 GB disk space**
- Internet connectivity for the initial download

The victim and Kali containers are intentionally **not exposed** to host ports.

---

# Published Ports

| Service | Default Port |
|---------|-------------|
| Wazuh Agent Traffic | **15140** |
| Wazuh Enrollment | **15150** |
| Syslog (UDP) | **5514** |
| Wazuh API | **55000** |
| Wazuh Dashboard | **443 (https://localhost)** |
| CALDERA | **8888** |

If any port conflicts with an existing installation, override it before starting:

```powershell
$env:WAZUH_AGENT_PORT='2514'
```

---

# Starting the Lab

Run PowerShell from the project directory.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\start-lab.ps1
```

The first startup may take **15–30 minutes** while Docker downloads images and initializes services.

---

# Accessing the Lab

## Wazuh Dashboard

```
https://localhost
```

Default credentials:

```
Username: admin
Password: SecretPassword
```

---

## CALDERA

```
http://localhost:8888
```
| Username | Password                                    |
| -------- | ------------------------------------------- |
| red      | ZtBdWbYBDL2dcPnaHOY6SVxsrXCIX2gDNrhxUExIO3I |
| blue     | bzUQKv74fKgqj7LRJyX8pgfP-V7aMrvPMsqVzxaEiE4 |
Retrieve the generated administrator credentials:

```powershell
docker logs purple-caldera
```

---

## Optional CALDERA Image Override

If maintaining your own tested mirror or tag:

```powershell
$env:CALDERA_IMAGE='ghcr.io/mitre/caldera:latest'
```

---

# Validation

`start-lab.ps1` automatically performs:

- Configuration validation
- Docker image builds
- Service startup
- Linux victim enrollment
- Safe Nmap discovery test

To rerun validation:

```powershell
.\test-lab.ps1
```

---

# Troubleshooting

## Linux Victim Shows "Disconnected"

1. Open Wazuh Dashboard.
2. Navigate to **Agents**.
3. Remove the stale **linux-victim** entry.
4. Execute:

```powershell
.\repair-linux-victim.ps1
```

The script will:

- Re-register the agent
- Persist the enrollment key
- Reapply Suricata log forwarding policy

---

## External Ubuntu Victim

See:

```
ubuntu-victim/
└── Reconnect-UbuntuVictim.md
```

---

## Wazuh Manager Startup Problems

If after approximately 10 minutes the manager still reports:

```
queue/db/wdb missing
```

Run diagnostics:

```powershell
.\diagnose-lab.ps1
```

Review the generated diagnostics, paying particular attention to:

- `oom=true`
- Manager exit code
- Wazuh configuration errors

---

# Attack Simulation

Only perform authorized testing against the included Linux victim.

## Nmap Service Discovery

```powershell
docker exec purple-kali nmap -sV linux-victim
```

---

## Port Connectivity Check

```powershell
docker exec purple-kali sh -c 'for p in 80 22 443; do nc -zv linux-victim $p; done'
```

---

# Monitoring in Wazuh

Useful search filters:

## Suricata Network Events

```text
data.location:/var/log/suricata/eve.json
```

---

## Purple Team Detection Rules

```text
rule.groups:purple_team
```

Also explore:

- Security Events
- MITRE ATT&CK dashboards
- Alert triage views

---

# Windows Victim

Docker Desktop running Linux containers cannot accurately emulate a Windows endpoint with:

- Windows Event Logs
- Sysmon
- Native Windows telemetry

Instead:

1. Create an isolated Windows VM (Hyper-V recommended).
2. Connect it to a host-only or isolated network.
3. Expose the required Wazuh manager ports.
4. Run:

```text
windows-victim/
└── Install-WindowsVictim.ps1
```

Execute the installer from an **elevated PowerShell session**.

> **Do not run attack simulations against the Windows host operating system.**

---

# Stopping the Lab

```powershell
.\stop-lab.ps1
```

---

# Complete Reset

To remove all persistent Wazuh and CALDERA data:

```powershell
docker compose down -v
```

Run the command from:

```text
vendor/
└── wazuh-docker/
    └── single-node/
```

Then remove:

```text
vendor/wazuh-docker
```

This performs a complete clean reset.

---

# Safety Guidelines

- Keep the entire stack on Docker's private bridge network.
- Test only systems that you own or are explicitly authorized to assess.
- Never expose Wazuh, CALDERA, manager, or agent ports directly to untrusted networks.
- Use the lab solely for defensive research, purple teaming, and detection engineering.

---

# Project

# 🟣 Purple Team Platform

An isolated Docker-based environment for learning, detection engineering, adversary emulation, and security operations using **Kali Linux**, **MITRE CALDERA**, **Suricata**, and **Wazuh**.
