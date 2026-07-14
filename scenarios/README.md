# Authorized lab exercises

These simulations are deliberately limited to the isolated `linux-victim`
container. They perform no exploitation, credential attempts, persistence, or
changes to the victim.

From PowerShell at the repository root:

```powershell
.\run-purple-scenario.ps1 -Scenario Reconnaissance
.\run-purple-scenario.ps1 -Scenario WebProbe
```

`Reconnaissance` runs a TCP connect scan for ports 22, 80, and 443. Suricata
generates network telemetry, which appears in **Purple Lab - Threat Detection**.

`WebProbe` makes one tagged request to the victim's nginx service. Wazuh reads
the nginx access log and raises the `purple_team` / `web_probe` alert. Find it
with `rule.groups: purple_team and rule.groups: web_probe`.

The individual shell scripts can also be run inside the Kali container:

```sh
sh /opt/purple/scenarios/01-reconnaissance.sh
sh /opt/purple/scenarios/02-web-probe.sh
```
