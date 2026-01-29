#!/bin/bash
set -e

# Paths
DEFAULT_CONFIG="/etc/moltbot/moltbot.default.json"
CONFIG_FILE="$MOLTBOT_STATE_DIR/moltbot.json"
TS_STATE_DIR="${TS_STATE_DIR:-/data/tailscale}"

# Ensure directories exist
mkdir -p "$MOLTBOT_STATE_DIR" "$MOLTBOT_WORKSPACE_DIR" "$MOLTBOT_STATE_DIR/memory" "$TS_STATE_DIR"

# Configure s3cmd for DO Spaces
configure_s3cmd() {
  cat > /tmp/.s3cfg << EOF
[default]
access_key = ${LITESTREAM_ACCESS_KEY_ID}
secret_key = ${LITESTREAM_SECRET_ACCESS_KEY}
host_base = ${SPACES_ENDPOINT}
host_bucket = %(bucket)s.${SPACES_ENDPOINT}
use_https = True
EOF
}

# Restore from Spaces backup if configured
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Restoring state from Spaces backup..."
  configure_s3cmd

  # Restore moltbot state files (config, devices, sessions) via tar
  STATE_BACKUP_PATH="s3://${SPACES_BUCKET}/moltbot/state-backup.tar.gz"
  if s3cmd -c /tmp/.s3cfg ls "$STATE_BACKUP_PATH" 2>/dev/null | grep -q state-backup; then
    echo "Downloading moltbot state backup..."
    s3cmd -c /tmp/.s3cfg get "$STATE_BACKUP_PATH" /tmp/state-backup.tar.gz && \
      tar -xzf /tmp/state-backup.tar.gz -C "$MOLTBOT_STATE_DIR" || \
      echo "Warning: failed to restore moltbot state backup (continuing)"
    rm -f /tmp/state-backup.tar.gz
  else
    echo "No moltbot state backup found (first deployment)"
  fi

  # Restore Tailscale state
  TS_BACKUP_PATH="s3://${SPACES_BUCKET}/moltbot/tailscale-state.tar.gz"
  if s3cmd -c /tmp/.s3cfg ls "$TS_BACKUP_PATH" 2>/dev/null | grep -q tailscale-state; then
    echo "Downloading Tailscale state backup..."
    s3cmd -c /tmp/.s3cfg get "$TS_BACKUP_PATH" /tmp/tailscale-state.tar.gz && \
      tar -xzf /tmp/tailscale-state.tar.gz -C "$TS_STATE_DIR" || \
      echo "Warning: failed to restore Tailscale state backup (continuing)"
    rm -f /tmp/tailscale-state.tar.gz
  else
    echo "No Tailscale state backup found (first deployment)"
  fi

  # Restore SQLite memory database via Litestream
  echo "Restoring SQLite from Litestream..."
  litestream restore -if-replica-exists -config /etc/litestream.yml \
    "$MOLTBOT_STATE_DIR/memory/main.sqlite" || true
fi

# Show version
echo "Moltbot version: $(moltbot --version 2>/dev/null || echo 'unknown')"

# Generate a gateway token if not provided
if [ -z "$MOLTBOT_GATEWAY_TOKEN" ]; then
  export MOLTBOT_GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '=/+' | head -c 32)
  echo "Generated gateway token (ephemeral)"
fi

# Build config by merging mode-specific settings into default config
echo "Building config: $CONFIG_FILE"

# Start with default config as base
if [ -f "$DEFAULT_CONFIG" ]; then
  cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
  echo "Using default config from $DEFAULT_CONFIG"
else
  # Fallback minimal config if default doesn't exist
  echo '{"gateway": {"mode": "local"}}' > "$CONFIG_FILE"
  echo "Warning: Default config not found, using minimal config"
fi

# Tailscale gateway configuration
echo "Gateway mode: Tailscale"
MODE_CONFIG=$(cat << 'MODEEOF'
{
  "gateway": {
    "bind": "loopback",
    "tailscale": { "mode": "serve" },
    "auth": {
      "allowTailscale": true
    }
  }
}
MODEEOF
)

# Merge mode config into base config (deep merge)
jq --argjson mode "$MODE_CONFIG" '. * $mode' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" \
  && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Add Gradient AI provider if API key is set
if [ -n "$GRADIENT_API_KEY" ]; then
  echo "Adding Gradient AI provider to config"
  GRADIENT_CONFIG=$(cat << 'GRADIENTEOF'
{
  "models": {
    "mode": "merge",
    "providers": {
      "gradient": {
        "baseUrl": "https://inference.do-ai.run/v1",
        "api": "openai-completions",
        "models": [
          {
            "id": "llama3.3-70b-instruct",
            "name": "Llama 3.3 70B Instruct",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 128000,
            "maxTokens": 8192
          },
          {
            "id": "anthropic-claude-4.5-sonnet",
            "name": "Claude 4.5 Sonnet",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 8192
          },
          {
            "id": "anthropic-claude-opus-4.5",
            "name": "Claude Opus 4.5",
            "reasoning": true,
            "input": ["text"],
            "contextWindow": 200000,
            "maxTokens": 16384
          },
          {
            "id": "deepseek-r1-distill-llama-70b",
            "name": "DeepSeek R1 Distill Llama 70B",
            "reasoning": true,
            "input": ["text"],
            "contextWindow": 128000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "gradient/llama3.3-70b-instruct"
      }
    }
  }
}
GRADIENTEOF
)
  # Merge Gradient config into main config, injecting the API key
  jq --argjson gradient "$GRADIENT_CONFIG" \
     --arg apiKey "$GRADIENT_API_KEY" \
     '. * $gradient | .models.providers.gradient.apiKey = $apiKey' \
     "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

echo "Final config:"
jq '.' "$CONFIG_FILE"

# Backup function for moltbot state files
backup_moltbot_state() {
  echo "Backing up moltbot state to Spaces..."
  cd "$MOLTBOT_STATE_DIR"
  # Backup JSON files (exclude memory/ which Litestream handles)
  tar -czf /tmp/state-backup.tar.gz \
    --exclude='memory' \
    --exclude='*.sqlite*' \
    --exclude='*.db*' \
    --exclude='gateway.*.lock' \
    . 2>/dev/null || true

  # Upload to Spaces using s3cmd
  if [ -f /tmp/state-backup.tar.gz ]; then
    s3cmd -c /tmp/.s3cfg put /tmp/state-backup.tar.gz \
      "s3://${SPACES_BUCKET}/moltbot/state-backup.tar.gz" && \
      echo "Moltbot state backup uploaded" || \
      echo "Warning: moltbot state backup upload failed"
    rm -f /tmp/state-backup.tar.gz
  fi
}

# Backup function for Tailscale state
backup_tailscale_state() {
  if [ -d "$TS_STATE_DIR" ]; then
    echo "Backing up Tailscale state to Spaces..."
    cd "$TS_STATE_DIR"
    tar -czf /tmp/tailscale-state.tar.gz . 2>/dev/null || true

    if [ -f /tmp/tailscale-state.tar.gz ]; then
      s3cmd -c /tmp/.s3cfg put /tmp/tailscale-state.tar.gz \
        "s3://${SPACES_BUCKET}/moltbot/tailscale-state.tar.gz" && \
        echo "Tailscale state backup uploaded" || \
        echo "Warning: Tailscale state backup upload failed"
      rm -f /tmp/tailscale-state.tar.gz
    fi
  fi
}

# Combined backup function
backup_state() {
  if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
    backup_moltbot_state
    backup_tailscale_state
  fi
}

# Background backup loop (every 5 minutes)
start_backup_loop() {
  while true; do
    sleep 300
    backup_state
  done
}

# Graceful shutdown handler
shutdown_handler() {
  echo "Shutting down, saving state..."
  backup_state
  exit 0
}
trap shutdown_handler SIGTERM SIGINT

# Start Tailscale daemon (required for networking)
echo "Starting Tailscale daemon..."
export TS_STATE_DIR
/usr/local/bin/containerboot &

# Start SSH server if enabled
if [ "${ENABLE_SSH:-false}" = "true" ]; then
  echo "Starting SSH server..."
  # Generate host keys if they don't exist
  sudo ssh-keygen -A 2>/dev/null || true
  # Start sshd in the background
  sudo /usr/sbin/sshd
  echo "SSH server started on port 22"
fi

# Start gateway - all configuration is in the config file
echo "Starting moltbot gateway..."
if [ -n "$LITESTREAM_ACCESS_KEY_ID" ] && [ -n "$SPACES_BUCKET" ]; then
  echo "Mode: Litestream + state backup enabled"

  # Start periodic backup in background
  start_backup_loop &

  # Run gateway with Litestream for SQLite replication
  litestream replicate -config /etc/litestream.yml \
    -exec "moltbot gateway --allow-unconfigured" &
  GATEWAY_PID=$!

  # Wait for gateway and handle shutdown
  wait $GATEWAY_PID
else
  echo "Mode: ephemeral (no persistence)"
  exec moltbot gateway --allow-unconfigured
fi
