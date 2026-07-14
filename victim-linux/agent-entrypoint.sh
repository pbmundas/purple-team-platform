#!/bin/sh
set -eu

# The centralized policy collects this application-style audit log.  Create it
# before the agent starts so collection begins on the first boot.
mkdir -p /var/log/purple
touch /var/log/purple/auth.log
# Keep the intentionally simple HTTP surface available for the tagged web
# probe scenario. Nginx daemonizes; Wazuh remains the container foreground
# process below.
(nginx 2>/dev/null || true)
exec /init "$@"
