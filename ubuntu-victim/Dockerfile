FROM wazuh/wazuh-agent:4.14.6

USER root
RUN if command -v dnf >/dev/null; then \
      dnf install -y nginx procps-ng iproute nmap-ncat && dnf clean all; \
    else \
      apt-get update && apt-get install -y --no-install-recommends nginx curl procps iproute2 netcat-openbsd \
      && rm -rf /var/lib/apt/lists/*; \
    fi
COPY agent-entrypoint.sh /usr/local/bin/purple-agent-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/purple-agent-entrypoint \
 && chmod 0555 /usr/local/bin/purple-agent-entrypoint
ENTRYPOINT ["/usr/local/bin/purple-agent-entrypoint"]
