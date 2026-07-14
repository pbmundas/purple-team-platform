#!/bin/sh
set -eu
mkdir -p /var/log/purple
touch /var/log/purple/auth.log
(nginx 2>/dev/null || true)
exec /init
