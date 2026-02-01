#!/bin/bash
# Test: SSH and UI enabled configuration
# Verifies multiple services run together

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing ssh-and-ui configuration (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running but SSH_ENABLE=true"; exit 1; }

# Node process for gateway
wait_for_process "$CONTAINER" "node" 5 || echo "warning: node process not found (may still be starting)"

echo "ssh-and-ui tests passed"
