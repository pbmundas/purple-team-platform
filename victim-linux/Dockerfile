FROM wazuh/wazuh-agent:4.14.6
USER root
RUN if command -v dnf >/dev/null; then \
      dnf install -y nginx procps-ng iproute nmap-ncat && dnf clean all; \
    else \
      apt-get update && apt-get install -y --no-install-recommends nginx curl procps iproute2 netcat-openbsd \
      && rm -rf /var/lib/apt/lists/*; \
    fi
COPY agent-entrypoint.sh /usr/local/bin/purple-agent-entrypoint
RUN chmod 0555 /usr/local/bin/purple-agent-entrypoint
ENTRYPOINT ["/usr/local/bin/purple-agent-entrypoint"]
# Keep the image's original entrypoint and ossec.conf. Its supported
# WAZUH_MANAGER/WAZUH_REGISTRATION_* environment variables register the agent
# at startup. Telemetry policy is distributed by the manager's agent.conf.
