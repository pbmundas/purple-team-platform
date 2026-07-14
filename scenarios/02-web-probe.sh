#!/bin/sh
# Lab-only HTTP probing.  The distinctive path and user agent make the event
# easy to find and alert on; the script does not submit credentials or data.
set -eu

target="${1:-linux-victim}"
if [ "$target" != "linux-victim" ]; then
  echo "Refusing: this simulation is restricted to linux-victim." >&2
  exit 64
fi

marker="purple-lab-probe-$(date +%s)"
url="http://$target/$marker"
echo "[purple-lab] benign HTTP probe: $url"
attempt=1
while [ "$attempt" -le 10 ]; do
  if curl --silent --show-error --connect-timeout 2 --max-time 5 -o /dev/null \
    -A "PurpleLab-Simulation/1.0" "$url"; then
    echo "[purple-lab] HTTP request completed"
    break
  fi
  if [ "$attempt" -eq 10 ]; then
    echo "[purple-lab] victim web service was unavailable" >&2
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 1
done
echo "[purple-lab] marker: $marker"
