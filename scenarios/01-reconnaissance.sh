#!/bin/sh
# Lab-only TCP service discovery.  No exploits, authentication attempts, or
# non-lab targets are allowed.
set -eu

target="${1:-linux-victim}"
if [ "$target" != "linux-victim" ]; then
  echo "Refusing: this simulation is restricted to linux-victim." >&2
  exit 64
fi

echo "[purple-lab] TCP service discovery against $target"
exec nmap -sT -Pn -n --reason -p 22,80,443 "$target"
