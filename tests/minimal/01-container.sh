#!/bin/bash
# Test: Container responsiveness
# Verifies base container starts and responds

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing container responsiveness (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }
echo "✓ Container is responsive"

echo "Container tests passed"
