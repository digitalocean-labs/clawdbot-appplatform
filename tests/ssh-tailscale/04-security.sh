#!/bin/bash
# Test: SSH security / negative test cases
# Verifies unauthorized access is denied

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing SSH security (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Wait for sshd to be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

CI_KEY="$HOME/.ssh/id_ed25519_test"

# Test password authentication is disabled
echo "Testing password authentication is disabled..."
docker exec "$CONTAINER" bash -c '
    useradd -m pwdtestuser 2>/dev/null || true
    echo "pwdtestuser:testpass123" | chpasswd
'
if docker exec "$CONTAINER" su - ubuntu -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o PreferredAuthentications=password pwdtestuser@localhost whoami" 2>/dev/null; then
    echo "error: Password authentication should be disabled"
    docker exec "$CONTAINER" userdel -r pwdtestuser 2>/dev/null || true
    exit 1
fi
echo "✓ Password authentication disabled"
docker exec "$CONTAINER" userdel -r pwdtestuser 2>/dev/null || true

# Test non-localaccess user cannot SSH to root
echo "Testing non-localaccess user cannot SSH to root..."
docker exec "$CONTAINER" bash -c '
    useradd -m testuser 2>/dev/null || true
    mkdir -p /home/testuser/.ssh
    ssh-keygen -t ed25519 -N "" -f /home/testuser/.ssh/id_ed25519 -C "testuser@test" >/dev/null 2>&1
    chown -R testuser:testuser /home/testuser/.ssh
'
if docker exec "$CONTAINER" su - testuser -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 root@localhost whoami" 2>/dev/null; then
    echo "error: Non-localaccess user should not SSH to root"
    docker exec "$CONTAINER" userdel -r testuser 2>/dev/null || true
    exit 1
fi
echo "✓ Non-localaccess user correctly denied"
docker exec "$CONTAINER" userdel -r testuser 2>/dev/null || true

# Test external SSH with unauthorized key is denied
if [ -f "$CI_KEY" ]; then
    echo "Testing unauthorized SSH key is denied..."
    WRONG_KEY="/tmp/wrong_key_$$"
    ssh-keygen -t ed25519 -N "" -f "$WRONG_KEY" -C "unauthorized@key" >/dev/null 2>&1
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -o ConnectTimeout=5 -i "$WRONG_KEY" -p 2222 ubuntu@localhost whoami 2>/dev/null; then
        echo "error: Unauthorized key should be denied"
        rm -f "$WRONG_KEY" "${WRONG_KEY}.pub"
        exit 1
    fi
    echo "✓ Unauthorized key correctly denied"
    rm -f "$WRONG_KEY" "${WRONG_KEY}.pub"

    # Test root login from external is denied
    echo "Testing root login from external is denied..."
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -o ConnectTimeout=5 -i "$CI_KEY" -p 2222 root@localhost whoami 2>/dev/null; then
        echo "error: External root login should be denied"
        exit 1
    fi
    echo "✓ External root login correctly denied"
else
    echo "SKIP: CI test key not found"
fi

echo "SSH security tests passed"
