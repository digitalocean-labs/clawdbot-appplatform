#!/bin/bash
# Test: Persistence services disabled
# Verifies backup and prune services are not running when persistence is disabled

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing persistence disabled (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Backup service should NOT be running (no persistence configured)
assert_service_down "$CONTAINER" "backup" || exit 1
assert_service_down "$CONTAINER" "prune" || exit 1

echo "Persistence disabled tests passed"
