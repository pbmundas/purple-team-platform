#!/bin/sh
set -eu

mkdir -p /var/log/purple
touch /var/log/purple/auth.log

# Keep the authorized Caldera lab agent persistent across container restarts.
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
        -paw "${CALDERA_PAW:-purpleubu}" \
        -v >> "$state_dir/sandcat.log" 2>&1 || true
      sleep 5
    done
  ) &
}

start_caldera_agent
(nginx 2>/dev/null || true)
exec /init "$@"
