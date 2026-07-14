# Reconnect an external Ubuntu victim to Docker Wazuh

The Docker lab publishes Wazuh agent traffic on **15140/TCP** and enrollment on **15150/TCP**. A pre-existing Ubuntu agent configured for Wazuh's defaults (1514/1515) will show as disconnected.

Run these commands on the Ubuntu VM, replacing `DOCKER_HOST_IP` with the Windows host IP address reachable by the VM. Do not use `localhost` unless the Wazuh manager is installed on the Ubuntu VM itself.

```bash
sudo cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.backup.$(date +%F-%H%M%S)
sudo sed -i -E 's#(<address>)[^<]+(</address>)#\1DOCKER_HOST_IP\2#; s#(<port>)1514(</port>)#\115140\2#; s#(<manager_address>)[^<]+(</manager_address>)#\1DOCKER_HOST_IP\2#; s#(<port>)1515(</port>)#\115150\2#' /var/ossec/etc/ossec.conf
sudo systemctl restart wazuh-agent
sudo systemctl status wazuh-agent --no-pager
sudo tail -n 50 /var/ossec/logs/ossec.log
```

From Ubuntu, verify both ports are reachable:

```bash
nc -zv DOCKER_HOST_IP 15140 15150
```

If the VM cannot reach them, allow inbound TCP 15140 and 15150 in Windows Defender Firewall and confirm Docker Desktop is running. Once the agent reconnects, refresh **Wazuh → Agents**.

If your lab uses custom values, substitute the values selected through `WAZUH_AGENT_PORT` and `WAZUH_REGISTRATION_PORT`.
