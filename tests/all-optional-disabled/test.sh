#!/bin/bash
# Test: All optional features disabled
# Verifies explicit false values are handled correctly

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing all-optional-disabled configuration (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should NOT be running (process and service)
assert_process_not_running "$CONTAINER" "sshd" || exit 1
assert_service_down "$CONTAINER" "sshd" || exit 1

# Tailscale should NOT be running (process and service)
assert_process_not_running "$CONTAINER" "tailscaled" || exit 1
assert_service_down "$CONTAINER" "tailscale" || exit 1

# ngrok should NOT be running (process and service)
assert_process_not_running "$CONTAINER" "ngrok" || exit 1
assert_service_down "$CONTAINER" "ngrok" || exit 1

# Backup service should NOT be running (no persistence configured)
assert_service_down "$CONTAINER" "backup" || exit 1
assert_service_down "$CONTAINER" "prune" || exit 1

echo "all-optional-disabled tests passed"
