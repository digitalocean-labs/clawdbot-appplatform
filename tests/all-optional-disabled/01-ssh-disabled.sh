#!/bin/bash
# Test: SSH disabled
# Verifies SSH service is not running when disabled

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing SSH disabled (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should NOT be running (process and service)
assert_process_not_running "$CONTAINER" "sshd" || exit 1
assert_service_down "$CONTAINER" "sshd" || exit 1

echo "SSH disabled tests passed"
