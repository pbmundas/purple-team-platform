FROM kalilinux/kali-rolling
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap netcat-traditional curl wget iputils-ping iproute2 dnsutils python3 python3-pip \
    git powershell && rm -rf /var/lib/apt/lists/* \
 && git clone --depth 1 https://github.com/redcanaryco/atomic-red-team.git /opt/atomic-red-team
COPY entrypoint.sh /usr/local/bin/purple-entrypoint
# Source files are edited from Windows as well as Linux; normalize line
# endings so the container can always resolve the /bin/sh interpreter.
RUN sed -i 's/\r$//' /usr/local/bin/purple-entrypoint \
 && chmod 0555 /usr/local/bin/purple-entrypoint
ENTRYPOINT ["/usr/local/bin/purple-entrypoint"]
