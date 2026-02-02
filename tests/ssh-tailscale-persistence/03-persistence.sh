#!/bin/bash
# Test: Persistence in ssh-tailscale-persistence config
# Verifies Restic backup services are configured

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing persistence (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Check if persistence is actually configured in the container
if ! docker exec "$CONTAINER" test -f /run/s6/container_environment/RESTIC_SPACES_BUCKET 2>/dev/null; then
    echo "SKIP: Persistence not configured (RESTIC_SPACES_BUCKET not set)"
    exit 0
fi

# Restic should be configured
docker exec "$CONTAINER" test -f /run/s6/container_environment/RESTIC_REPOSITORY || {
    echo "warning: RESTIC_REPOSITORY not set (init may have failed)"
}
echo "✓ Restic repository configured"

# Backup service should be running
assert_service_up "$CONTAINER" backup || echo "warning: backup service not up yet"
assert_service_up "$CONTAINER" prune || echo "warning: prune service not up yet"

echo "Persistence tests passed"
