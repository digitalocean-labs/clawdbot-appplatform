#!/bin/bash
# Test: SSH in ssh-tailscale-persistence config
# Verifies SSH works with all features enabled

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing SSH (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

# Local SSH - all combinations
assert_ssh_works "$CONTAINER" ubuntu ubuntu || exit 1
assert_ssh_works "$CONTAINER" ubuntu root || exit 1
assert_ssh_works "$CONTAINER" ubuntu openclaw || exit 1
assert_ssh_works "$CONTAINER" root ubuntu || exit 1
assert_ssh_works "$CONTAINER" root root || exit 1
assert_ssh_works "$CONTAINER" root openclaw || exit 1

# External SSH
CI_KEY="$HOME/.ssh/id_ed25519_test"
if [ -f "$CI_KEY" ]; then
    wait_for_ssh_port localhost 2222 || { echo "error: SSH port 2222 not reachable"; exit 1; }
    assert_external_ssh_works localhost 2222 ubuntu "$CI_KEY" || exit 1

    # Chained SSH
    echo "Testing chained SSH..."
    RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -o ConnectTimeout=10 -i "$CI_KEY" -p 2222 ubuntu@localhost \
        'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost whoami' 2>/dev/null)
    [ "$RESULT" = "root" ] || { echo "error: Chained SSH failed"; exit 1; }
    echo "✓ Chained SSH works"
else
    echo "SKIP: CI test key not found"
fi

echo "SSH tests passed"
