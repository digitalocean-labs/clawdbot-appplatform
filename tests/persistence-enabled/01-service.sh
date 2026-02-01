#!/bin/bash
# Test: Persistence services initialized
# Verifies backup/prune services start and restic repository is ready

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

# Helper to run commands with restic environment loaded
run_with_restic_env() {
    docker exec "$CONTAINER" bash -c "source /etc/s6-overlay/lib/env-utils.sh && source_env_prefix RESTIC_ && $*"
}

echo "Testing persistence services (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Check if persistence is actually configured (CI may skip if no credentials)
if ! docker exec "$CONTAINER" test -f /run/s6/container_environment/RESTIC_SPACES_BUCKET 2>/dev/null; then
    echo "SKIP: Persistence not configured (RESTIC_SPACES_BUCKET not set)"
    echo "Set DO_SPACES_ACCESS_KEY_ID and DO_SPACES_SECRET_ACCESS_KEY secrets to enable"
    exit 0
fi

# Wait for backup service to be ready
wait_for_service "$CONTAINER" "backup" || exit 1

# Prune service should also be running
assert_service_up "$CONTAINER" "prune" || exit 1

# Verify restic repository is initialized
if ! run_with_restic_env "restic snapshots --latest 1" >/dev/null 2>&1; then
    echo "error: Restic repository not initialized"
    exit 1
fi
echo "✓ Restic repository initialized"

# Verify backup script exists and is executable
docker exec "$CONTAINER" test -x /usr/local/bin/restic-backup || { echo "error: restic-backup script not executable"; exit 1; }
echo "✓ restic-backup script available"

echo "Persistence service tests passed"
