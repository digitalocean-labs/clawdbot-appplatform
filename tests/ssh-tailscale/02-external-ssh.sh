#!/bin/bash
# Test: External SSH via port 2222
# Verifies SSH access from outside the container

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing external SSH (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Wait for sshd to be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

CI_KEY="$HOME/.ssh/id_ed25519_test"
if [ ! -f "$CI_KEY" ]; then
    echo "SKIP: CI test key not found"
    exit 0
fi

wait_for_ssh_port localhost 2222 || { echo "error: SSH port 2222 not reachable"; exit 1; }
assert_external_ssh_works localhost 2222 ubuntu "$CI_KEY" || exit 1

# Test chained SSH: external -> ubuntu -> root
echo "Testing chained SSH (external -> ubuntu -> root)..."
RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -i "$CI_KEY" -p 2222 ubuntu@localhost \
    'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost whoami' 2>/dev/null)
if [ "$RESULT" = "root" ]; then
    echo "✓ Chained SSH works: logged in as root"
else
    echo "error: Chained SSH failed, got: $RESULT"
    exit 1
fi

echo "External SSH tests passed"
