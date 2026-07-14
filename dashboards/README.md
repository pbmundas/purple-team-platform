# Threat-hunting dashboards

Run `./install-threat-hunting-dashboards.ps1` after the Wazuh stack is running. This version uses the current OpenSearch panel-reference format, avoiding the duplicate legacy references that prevented the custom dashboard views from rendering reliably. In Wazuh Dashboards, open **Dashboard** and select either:

- **Purple Lab - Threat Detection**: starts a demonstration with high-severity alerts, purple-team detections, and Suricata/IDS alerts.
- **Purple Lab - Threat Investigation**: pivots from agent activity into file-integrity changes and the monitored application-log source.

For a safe showcase event, run `./rehearse-threat-hunt.ps1`, set the dashboard time range to **Last 15 minutes**, and refresh. It writes only a unique marker to the lab's monitored log and the local rule raises a level-10 `purple_team`/`threat_hunt` alert. It does not run an attack.
