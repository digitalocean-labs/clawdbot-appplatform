#!/bin/bash
set -e

# Ensure directories exist
mkdir -p "$CLAWDBOT_STATE_DIR" "$CLAWDBOT_WORKSPACE_DIR"

# Restore from Litestream backup if configured
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Restoring from Litestream backup..."
  litestream restore -if-replica-exists -config /etc/litestream.yml \
    "$CLAWDBOT_STATE_DIR/memory.db" || true
fi

# Update to latest Clawdbot
echo "Checking for Clawdbot updates..."
npm update -g clawdbot --prefer-online 2>/dev/null || true

# Show version
echo "Clawdbot version: $(clawdbot --version 2>/dev/null || echo 'unknown')"

# Run doctor to ensure config is valid
echo "Running clawdbot doctor..."
clawdbot doctor --non-interactive || true

# Get the global node_modules path
CLAWDBOT_PATH=$(npm root -g)/clawdbot/dist/index.js

# Start with or without Litestream replication
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Starting Clawdbot with Litestream replication..."
  exec litestream replicate -config /etc/litestream.yml \
    -exec "node $CLAWDBOT_PATH gateway run --bind 0.0.0.0 --port ${PORT:-8080}"
else
  echo "Starting Clawdbot (ephemeral mode - no persistence)..."
  exec node "$CLAWDBOT_PATH" gateway run --bind 0.0.0.0 --port "${PORT:-8080}"
fi
