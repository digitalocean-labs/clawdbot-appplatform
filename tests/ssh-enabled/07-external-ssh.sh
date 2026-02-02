#!/bin/bash
# Test: External SSH access via port 2222
# Verifies SSH access from outside the container

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing external SSH access (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Wait for sshd to be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

CI_KEY="$HOME/.ssh/id_ed25519_test"
if [ ! -f "$CI_KEY" ]; then
    echo "SKIP: CI test key not found, skipping external SSH tests"
    exit 0
fi

wait_for_ssh_port localhost 2222 || { echo "error: SSH port 2222 not reachable"; exit 1; }

# Test external SSH to ubuntu
assert_external_ssh_works localhost 2222 ubuntu "$CI_KEY" || exit 1

# Test command execution via external SSH
echo "Testing command execution via external SSH..."
RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -o ConnectTimeout=10 -i "$CI_KEY" -p 2222 ubuntu@localhost 'hostname' 2>/dev/null)
echo "✓ External command output: $RESULT"

# Test chained SSH: external -> ubuntu -> root
echo "Testing chained SSH (external -> ubuntu -> root)..."
RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -o ConnectTimeout=10 -i "$CI_KEY" -p 2222 ubuntu@localhost \
    'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes root@localhost whoami' 2>/dev/null)
[ "$RESULT" = "root" ] || { echo "error: Chained SSH failed, got: $RESULT"; exit 1; }
echo "✓ Chained SSH works"

# Test file transfer capability
echo "Testing SCP file transfer..."
echo "test-content-$$" > /tmp/test-upload-$$.txt
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -i "$CI_KEY" -P 2222 /tmp/test-upload-$$.txt ubuntu@localhost:/tmp/ 2>/dev/null || { echo "error: SCP upload failed"; exit 1; }
RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
    -o ConnectTimeout=10 -i "$CI_KEY" -p 2222 ubuntu@localhost "cat /tmp/test-upload-$$.txt" 2>/dev/null)
[ "$RESULT" = "test-content-$$" ] || { echo "error: SCP content mismatch"; exit 1; }
echo "✓ SCP file transfer works"
rm -f /tmp/test-upload-$$.txt

echo "External SSH tests passed"
