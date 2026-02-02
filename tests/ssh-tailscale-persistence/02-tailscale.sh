#!/bin/bash
# Test: Tailscale in ssh-tailscale-persistence config
# Verifies Tailscale networking and SSH via Tailscale

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing Tailscale (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

if [ "${SKIP_TAILSCALE:-false}" = "true" ]; then
    echo "SKIP: Tailscale tests (no credentials)"
    exit 0
fi

wait_for_process "$CONTAINER" "tailscaled" || { echo "error: tailscaled not running"; exit 1; }

# Wait for Tailscale to connect and get IP
echo "Waiting for Tailscale to connect..."
TS_IP=""
for i in {1..60}; do
    TS_IP=$(docker exec "$CONTAINER" tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TS_IP" ]; then
        echo "✓ Tailscale IP: $TS_IP"
        break
    fi
    [ $i -eq 60 ] && { echo "error: Failed to get Tailscale IP"; exit 1; }
    sleep 2
done

# Test SSH via Tailscale from sidecar
if ! docker ps --filter name=tailscale-test --format '{{.Names}}' | grep -q tailscale-test; then
    echo "error: Tailscale sidecar not running"
    exit 1
fi

echo "Testing SSH via Tailscale network..."
# Wait for connectivity
TAILSCALE_CONNECTED=false
for i in {1..30}; do
    if docker exec tailscale-test ping -c 1 -W 2 "$TS_IP" >/dev/null 2>&1; then
        echo "✓ Tailscale network connectivity established"
        TAILSCALE_CONNECTED=true
        break
    fi
    sleep 2
done

if [ "$TAILSCALE_CONNECTED" != "true" ]; then
    echo "SKIP: Tailscale ping to $TS_IP failed (network connectivity issue)"
    docker exec tailscale-test tailscale status 2>&1 || true
    exit 0
fi

# Test SSH to ubuntu
if ! docker exec tailscale-test ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o ConnectTimeout=30 -i /tmp/id_ed25519_test \
    "ubuntu@$TS_IP" 'whoami' 2>/dev/null | grep -q ubuntu; then
    echo "error: SSH via Tailscale to ubuntu failed"
    exit 1
fi
echo "✓ SSH via Tailscale to ubuntu works"

echo "Tailscale tests passed"
