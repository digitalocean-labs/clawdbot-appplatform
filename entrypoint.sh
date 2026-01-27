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

# Show version (image is rebuilt weekly with latest clawdbot)
echo "Clawdbot version: $(clawdbot --version 2>/dev/null || echo 'unknown')"

# Generate a gateway token if not provided (required for LAN binding)
if [ -z "$CLAWDBOT_GATEWAY_TOKEN" ]; then
  export CLAWDBOT_GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=/+' | head -c 32)
  echo "Generated gateway token (ephemeral)"
fi

# Configure gateway for container deployment via environment
export CLAWDBOT_GATEWAY_MODE=local
export CLAWDBOT_GATEWAY_BIND=lan
export CLAWDBOT_GATEWAY_PORT="${PORT:-8080}"

echo "Gateway config: mode=$CLAWDBOT_GATEWAY_MODE bind=$CLAWDBOT_GATEWAY_BIND port=$CLAWDBOT_GATEWAY_PORT"

# Get the global node_modules path
CLAWDBOT_PATH=$(npm root -g)/clawdbot/dist/index.js

# Start with or without Litestream replication
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Starting Clawdbot with Litestream replication..."
  exec litestream replicate -config /etc/litestream.yml \
    -exec "node $CLAWDBOT_PATH gateway run --allow-unconfigured --bind 0.0.0.0 --port ${PORT:-8080}"
else
  echo "Starting Clawdbot (ephemeral mode - no persistence)..."
  exec node "$CLAWDBOT_PATH" gateway run --allow-unconfigured --bind 0.0.0.0 --port "${PORT:-8080}"
fi
