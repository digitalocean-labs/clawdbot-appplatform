#!/bin/bash
# Test: SSH and UI enabled configuration
# Verifies multiple services run together and SSH client connectivity works

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

# --- Local SSH Access Tests ---
echo ""
echo "Testing local SSH connectivity..."

# Test ubuntu -> root SSH (key feature)
assert_ssh_works "$CONTAINER" ubuntu root || exit 1

# --- External SSH Access Tests ---
echo ""
echo "Testing external SSH access..."

CI_KEY="$HOME/.ssh/id_ed25519_test"
if [ -f "$CI_KEY" ]; then
    wait_for_ssh_port localhost 2222 || { echo "error: SSH port 2222 not reachable"; exit 1; }
    assert_external_ssh_works localhost 2222 ubuntu "$CI_KEY" || exit 1
else
    echo "warning: CI test key not found, skipping external SSH tests"
fi

echo ""
echo "ssh-and-ui tests passed"
