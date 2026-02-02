#!/bin/bash
# Test: Security / negative test cases
# Verifies unauthorized access is denied

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing security (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Wait for sshd to be running
wait_for_process "$CONTAINER" "sshd" || { echo "error: sshd not running"; exit 1; }

CI_KEY="$HOME/.ssh/id_ed25519_test"

# Password auth disabled
echo "Testing password authentication is disabled..."
docker exec "$CONTAINER" bash -c 'useradd -m pwdtest 2>/dev/null || true; echo "pwdtest:pass123" | chpasswd'
if docker exec "$CONTAINER" su - ubuntu -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o PreferredAuthentications=password pwdtest@localhost whoami" 2>/dev/null; then
    docker exec "$CONTAINER" userdel -r pwdtest 2>/dev/null || true
    echo "error: Password auth should be disabled"; exit 1
fi
echo "✓ Password authentication disabled"
docker exec "$CONTAINER" userdel -r pwdtest 2>/dev/null || true

# Non-localaccess user denied
echo "Testing non-localaccess user denied..."
docker exec "$CONTAINER" bash -c '
    useradd -m testuser 2>/dev/null || true
    mkdir -p /home/testuser/.ssh
    ssh-keygen -t ed25519 -N "" -f /home/testuser/.ssh/id_ed25519 -C "testuser" >/dev/null 2>&1
    chown -R testuser:testuser /home/testuser/.ssh
'
if docker exec "$CONTAINER" su - testuser -c \
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 root@localhost whoami" 2>/dev/null; then
    docker exec "$CONTAINER" userdel -r testuser 2>/dev/null || true
    echo "error: Non-localaccess user should be denied"; exit 1
fi
echo "✓ Non-localaccess user denied"
docker exec "$CONTAINER" userdel -r testuser 2>/dev/null || true

# Unauthorized key denied
if [ -f "$CI_KEY" ]; then
    echo "Testing unauthorized key denied..."
    WRONG_KEY="/tmp/wrong_key_$$"
    ssh-keygen -t ed25519 -N "" -f "$WRONG_KEY" -C "wrong" >/dev/null 2>&1
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -o ConnectTimeout=5 -i "$WRONG_KEY" -p 2222 ubuntu@localhost whoami 2>/dev/null; then
        rm -f "$WRONG_KEY" "${WRONG_KEY}.pub"
        echo "error: Unauthorized key should be denied"; exit 1
    fi
    echo "✓ Unauthorized key denied"
    rm -f "$WRONG_KEY" "${WRONG_KEY}.pub"

    # External root login denied
    echo "Testing external root login denied..."
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes \
        -o ConnectTimeout=5 -i "$CI_KEY" -p 2222 root@localhost whoami 2>/dev/null; then
        echo "error: External root login should be denied"; exit 1
    fi
    echo "✓ External root login denied"
else
    echo "SKIP: CI test key not found"
fi

echo "Security tests passed"
