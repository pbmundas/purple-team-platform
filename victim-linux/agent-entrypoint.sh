#!/bin/sh
set -eu

# The centralized policy collects this application-style audit log.  Create it
# before the agent starts so collection begins on the first boot.
mkdir -p /var/log/purple
touch /var/log/purple/auth.log

# Run a lab-scoped Caldera Sandcat agent alongside Wazuh. The agent binary and
# fixed PAW are held on a named volume so normal container restarts reconnect
# the same authorized lab asset instead of creating dead duplicate agents.
start_caldera_agent() {
  state_dir=/opt/purple/caldera
  agent="$state_dir/sandcat"
  mkdir -p "$state_dir"

  (
    while :; do
      if [ ! -x "$agent" ]; then
        tmp="$agent.tmp"
        rm -f "$tmp"
        if curl -fsS -X POST -H 'file:sandcat.go' -H 'platform:linux' \
          "${CALDERA_SERVER:-http://caldera:8888}/file/download" -o "$tmp"; then
          chmod 0700 "$tmp"
          mv "$tmp" "$agent"
        else
          rm -f "$tmp"
          sleep 5
          continue
        fi
      fi

      "$agent" \
        -server "${CALDERA_SERVER:-http://caldera:8888}" \
        -group "${CALDERA_GROUP:-red}" \
        -paw "${CALDERA_PAW:-purplelin}" \
        -v >> "$state_dir/sandcat.log" 2>&1 || true
      sleep 5
    done
  ) &
}

start_caldera_agent
# Keep the intentionally simple HTTP surface available for the tagged web
# probe scenario. Nginx daemonizes; Wazuh remains the container foreground
# process below.
(nginx 2>/dev/null || true)
exec /init "$@"
