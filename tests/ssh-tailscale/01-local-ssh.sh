#!/bin/bash
# Test: Local SSH in ssh-tailscale config
# Verifies SSH works inside the container

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing local SSH (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# SSH should be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

# Test local SSH connectivity for all user combinations
assert_ssh_works "$CONTAINER" ubuntu ubuntu || exit 1
assert_ssh_works "$CONTAINER" ubuntu root || exit 1
assert_ssh_works "$CONTAINER" ubuntu openclaw || exit 1
assert_ssh_works "$CONTAINER" root ubuntu || exit 1
assert_ssh_works "$CONTAINER" root root || exit 1
assert_ssh_works "$CONTAINER" root openclaw || exit 1

# Test command execution via local SSH
echo "Testing command execution via local SSH..."
RESULT=$(docker exec "$CONTAINER" su - ubuntu -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost 'hostname'" 2>/dev/null)
echo "✓ Command output: $RESULT"

echo "Local SSH tests passed"
