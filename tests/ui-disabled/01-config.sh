#!/bin/bash
# Test: UI disabled in configuration
# Verifies gateway runs in CLI-only mode

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

echo "Testing UI disabled config (container: $CONTAINER)..."

# Container should be running
docker exec "$CONTAINER" true || { echo "error: container not responsive"; exit 1; }

# Gateway config should have ui disabled
if docker exec "$CONTAINER" cat /data/.openclaw/openclaw.json 2>/dev/null | grep -q '"ui"'; then
    ui_enabled=$(docker exec "$CONTAINER" cat /data/.openclaw/openclaw.json | jq -r '.ui // false')
    if [ "$ui_enabled" = "true" ]; then
        echo "error: UI is enabled but ENABLE_UI=false"
        exit 1
    fi
fi
echo "✓ UI disabled in config"

echo "UI config tests passed"
