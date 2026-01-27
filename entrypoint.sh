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

# Configure gateway for container deployment
echo "Configuring gateway..."
clawdbot config set gateway.mode local 2>/dev/null || true
clawdbot config set gateway.bind lan 2>/dev/null || true
clawdbot config set gateway.port "${PORT:-8080}" 2>/dev/null || true

# Generate a gateway token if not provided (required for LAN binding)
if [ -z "$CLAWDBOT_GATEWAY_TOKEN" ]; then
  export CLAWDBOT_GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=/+' | head -c 32)
  echo "Generated gateway token (ephemeral)"
fi

# Run doctor to ensure config is valid
echo "Running clawdbot doctor..."
clawdbot doctor --non-interactive || true

# Get the global node_modules path
CLAWDBOT_PATH=$(npm root -g)/clawdbot/dist/index.js

# Start with or without Litestream replication
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Starting Clawdbot with Litestream replication..."
  exec litestream replicate -config /etc/litestream.yml \
    -exec "node $CLAWDBOT_PATH gateway run"
else
  echo "Starting Clawdbot (ephemeral mode - no persistence)..."
  exec node "$CLAWDBOT_PATH" gateway run
fi
