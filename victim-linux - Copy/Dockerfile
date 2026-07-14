FROM wazuh/wazuh-agent:4.14.6
USER root
RUN (apt-get update || true) && (apt-get install -y --no-install-recommends \
    nginx curl procps iproute2 netcat-openbsd || true) && rm -rf /var/lib/apt/lists/*
# Keep the image's original entrypoint and ossec.conf. Its supported
# WAZUH_MANAGER/WAZUH_REGISTRATION_* environment variables register the agent
# at startup. Telemetry policy is distributed by the manager's agent.conf.
