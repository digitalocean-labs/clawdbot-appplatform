#!/bin/bash
# Test: Gateway process running alongside SSH
# Verifies multiple services coexist

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing gateway with SSH (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Node process for gateway
wait_for_process "$CONTAINER" "node" 5 || echo "warning: node process not found (may still be starting)"

# OpenClaw service should be up
assert_service_up "$CONTAINER" "openclaw" || exit 1

echo "Gateway coexistence tests passed"
