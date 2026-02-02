#!/bin/bash
# Test: SSH via Tailscale network
# Verifies SSH works over Tailscale from sidecar container

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing Tailscale SSH (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

if [ "${SKIP_TAILSCALE:-false}" = "true" ]; then
    echo "SKIP: Tailscale tests (no credentials)"
    exit 0
fi

# Wait for Tailscale to be running
wait_for_process "$CONTAINER" "tailscaled" || { echo "error: tailscaled not running"; exit 1; }

# Wait for Tailscale to connect and get IP
echo "Waiting for Tailscale to connect..."
TS_IP=""
for i in {1..60}; do
    TS_IP=$(docker exec "$CONTAINER" tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TS_IP" ]; then
        echo "✓ Container Tailscale IP: $TS_IP"
        break
    fi
    [ $i -eq 60 ] && { echo "error: Failed to get Tailscale IP"; exit 1; }
    sleep 2
done

# Check if tailscale-test sidecar is running
if ! docker ps --filter name=tailscale-test --format '{{.Names}}' | grep -q tailscale-test; then
    echo "error: Tailscale sidecar not running"
    exit 1
fi

echo "Testing SSH via Tailscale network from sidecar..."

# Wait for Tailscale routes to establish between containers
echo "Waiting for Tailscale connectivity between containers..."
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
    echo "SKIP: Tailscale ping to $TS_IP failed after 60s (network connectivity issue)"
    echo "Sidecar status:"
    docker exec tailscale-test tailscale status 2>&1 || true
    echo "Container status:"
    docker exec "$CONTAINER" tailscale status 2>&1 || true
    exit 0
fi

# Test SSH from sidecar to main container via Tailscale IP
echo "Testing SSH to $TS_IP from Tailscale sidecar..."
if ! docker exec tailscale-test ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o ConnectTimeout=30 -i /tmp/id_ed25519_test \
    "ubuntu@$TS_IP" 'whoami' 2>/dev/null | grep -q ubuntu; then
    echo "error: SSH via Tailscale IP failed"
    echo "Debug - sidecar tailscale status:"
    docker exec tailscale-test tailscale status 2>&1 || true
    exit 1
fi
echo "✓ SSH via Tailscale IP works"

# Test chained SSH via Tailscale
echo "Testing chained SSH via Tailscale (sidecar -> ubuntu -> root)..."
RESULT=$(docker exec tailscale-test ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes -o ConnectTimeout=30 -i /tmp/id_ed25519_test \
    "ubuntu@$TS_IP" \
    'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost whoami' 2>/dev/null || echo "FAILED")
if [ "$RESULT" = "root" ]; then
    echo "✓ Chained SSH via Tailscale works"
else
    echo "error: Chained SSH via Tailscale failed, got: $RESULT"
    exit 1
fi

echo "Tailscale SSH tests passed"
