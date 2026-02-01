#!/bin/bash
# Test: SSH enabled configuration
# Verifies SSH service starts correctly

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing ssh-enabled configuration (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running but SSH_ENABLE=true"; exit 1; }

# SSH port should be listening (use netstat as fallback if ss not available)
if docker exec "$CONTAINER" command -v ss >/dev/null 2>&1; then
    docker exec "$CONTAINER" ss -tlnp | grep -q ":22 " || { echo "error: SSH not listening on port 22"; exit 1; }
else
    docker exec "$CONTAINER" netstat -tlnp 2>/dev/null | grep -q ":22 " || { echo "error: SSH not listening on port 22"; exit 1; }
fi
echo "✓ SSH listening on port 22"

# Authorized keys should be set up
docker exec "$CONTAINER" test -f /root/.ssh/authorized_keys || { echo "error: authorized_keys not found"; exit 1; }
echo "✓ authorized_keys exists"

echo "ssh-enabled tests passed"
