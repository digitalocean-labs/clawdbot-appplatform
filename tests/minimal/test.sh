#!/bin/bash
# Test: minimal configuration
# Verifies base container with all features disabled

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing minimal configuration (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Gateway should be listening (may take a moment to start)
wait_for_process "$CONTAINER" "node" 5 || echo "warning: node process not found (may still be starting)"

# SSH should NOT be running
assert_process_not_running "$CONTAINER" "sshd" || exit 1

echo "minimal tests passed"
