#!/bin/bash
# Test: Local SSH access inside container
# Verifies SSH works between users within the container

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing local SSH access (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Wait for sshd to be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

# Test all user combinations
assert_ssh_works "$CONTAINER" ubuntu ubuntu || exit 1
assert_ssh_works "$CONTAINER" ubuntu root || exit 1
assert_ssh_works "$CONTAINER" ubuntu openclaw || exit 1
assert_ssh_works "$CONTAINER" root ubuntu || exit 1
assert_ssh_works "$CONTAINER" root root || exit 1
assert_ssh_works "$CONTAINER" root openclaw || exit 1

# Test command execution
echo "Testing command execution via SSH..."
RESULT=$(docker exec "$CONTAINER" su - ubuntu -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost 'echo test-output-123'" 2>/dev/null)
[ "$RESULT" = "test-output-123" ] || { echo "error: Expected 'test-output-123', got '$RESULT'"; exit 1; }
echo "✓ Command execution works"

# Test environment variable passing (MOTD_SKIP)
echo "Testing MOTD_SKIP environment variable..."
docker exec "$CONTAINER" su - ubuntu -c \
    "MOTD_SKIP=1 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o SendEnv=MOTD_SKIP root@localhost 'echo \$MOTD_SKIP'" \
    2>/dev/null | grep -q "1" && echo "✓ MOTD_SKIP passed correctly" || echo "warning: MOTD_SKIP not passed (non-critical)"

echo "Local SSH tests passed"
