#!/bin/bash
# Test: SSH service is running and accessible
# Verifies sshd starts and port is listening

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing SSH service (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running but SSH_ENABLE=true"; exit 1; }

# SSH port should be listening (use bash /dev/tcp since ss/netstat may not be installed)
docker exec "$CONTAINER" bash -c 'echo > /dev/tcp/127.0.0.1/22' 2>/dev/null || { echo "error: SSH not listening on port 22"; exit 1; }
echo "✓ SSH listening on port 22"

# s6 service should be up
assert_service_up "$CONTAINER" "sshd" || exit 1

echo "SSH service tests passed"
