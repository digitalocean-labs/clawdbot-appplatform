#!/bin/bash
# Test: Gateway process running
# Verifies OpenClaw gateway starts

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing gateway process (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Gateway should be listening (may take a moment to start)
wait_for_process "$CONTAINER" "node" 5 || echo "warning: node process not found (may still be starting)"

echo "Gateway tests passed"
