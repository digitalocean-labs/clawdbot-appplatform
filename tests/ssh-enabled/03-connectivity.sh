#!/bin/bash
# Test: SSH connectivity
# Verifies actual SSH connection works with test key

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing SSH connectivity (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Create temporary test key
TEST_KEY_DIR=$(mktemp -d)
TEST_KEY="$TEST_KEY_DIR/test_key"
trap "rm -rf $TEST_KEY_DIR" EXIT

ssh-keygen -t ed25519 -f "$TEST_KEY" -N "" -q
echo "✓ Generated test key"

# Add test key to authorized_keys in container
TEST_PUBKEY=$(cat "$TEST_KEY.pub")
docker exec "$CONTAINER" bash -c "echo '$TEST_PUBKEY' >> /home/ubuntu/.ssh/authorized_keys"
echo "✓ Added test key to authorized_keys"

# Get container IP for SSH connection
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER")
if [ -z "$CONTAINER_IP" ]; then
    echo "error: Could not get container IP"
    exit 1
fi
echo "✓ Container IP: $CONTAINER_IP"

# Test SSH connection
SSH_OUTPUT=$(ssh -i "$TEST_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    -o BatchMode=yes \
    ubuntu@"$CONTAINER_IP" "echo 'SSH_TEST_SUCCESS'" 2>/dev/null) || {
    echo "error: SSH connection failed"
    exit 1
}

if [ "$SSH_OUTPUT" != "SSH_TEST_SUCCESS" ]; then
    echo "error: SSH command output unexpected: $SSH_OUTPUT"
    exit 1
fi
echo "✓ SSH connection successful"

# Test running a command via SSH
WHOAMI=$(ssh -i "$TEST_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o BatchMode=yes \
    ubuntu@"$CONTAINER_IP" "whoami" 2>/dev/null)

if [ "$WHOAMI" != "ubuntu" ]; then
    echo "error: Expected whoami=ubuntu, got: $WHOAMI"
    exit 1
fi
echo "✓ SSH command execution works (whoami=ubuntu)"

echo "SSH connectivity tests passed"
