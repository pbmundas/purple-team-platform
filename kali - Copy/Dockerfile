FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap netcat-traditional curl wget iputils-ping dnsutils python3 python3-pip \
    git powershell && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 https://github.com/redcanaryco/atomic-red-team.git /opt/atomic-red-team
COPY entrypoint.sh /usr/local/bin/purple-entrypoint
RUN chmod 0555 /usr/local/bin/purple-entrypoint
ENTRYPOINT ["/usr/local/bin/purple-entrypoint"]
