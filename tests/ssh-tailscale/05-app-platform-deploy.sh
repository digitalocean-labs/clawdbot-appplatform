#!/bin/bash
# Test: App Platform deployment
# Verifies the app can be deployed to DigitalOcean App Platform using doctl

set -e

CONTAINER=${1:?Usage: $0 <container-name>}
source "$(dirname "$0")/../lib.sh"

SPEC_FILE="$(dirname "$0")/app-ssh-local.spec.yaml"
APP_ID=""

echo "Testing App Platform deployment..."

# Check for required environment variables (doctl action sets DIGITALOCEAN_ACCESS_TOKEN)
if [ -z "$DIGITALOCEAN_ACCESS_TOKEN" ]; then
    echo "error: DIGITALOCEAN_ACCESS_TOKEN not set (doctl not configured)"
    exit 1
fi

if [ -z "$TS_AUTHKEY" ]; then
    echo "error: TS_AUTHKEY not set (required for app deployment)"
    exit 1
fi

# Verify doctl is available
if ! command -v doctl &>/dev/null; then
    echo "error: doctl not installed"
    exit 1
fi

# Verify spec file exists
if [ ! -f "$SPEC_FILE" ]; then
    echo "error: Spec file not found: $SPEC_FILE"
    exit 1
fi

# Generate unique app name
APP_NAME="openclaw-ci-test-$(date +%s)-$$"
echo "App name: $APP_NAME"

# Get current branch for the deployment
CURRENT_BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-main}}"
echo "Using branch: $CURRENT_BRANCH"

# Convert YAML spec to JSON and modify it
echo "Preparing app spec..."
APP_SPEC=$(yq -o=json "$SPEC_FILE" | jq \
    --arg name "$APP_NAME" \
    --arg branch "$CURRENT_BRANCH" \
    --arg ts_authkey "$TS_AUTHKEY" \
    --arg gateway_token "${OPENCLAW_GATEWAY_TOKEN:-test-token-$$}" \
    '
    .name = $name |
    .workers[0].name = $name |
    .workers[0].git.branch = $branch |
    .workers[0].envs = [
        .workers[0].envs[] |
        if .key == "TS_AUTHKEY" then .value = $ts_authkey
        elif .key == "OPENCLAW_GATEWAY_TOKEN" then .value = $gateway_token
        elif .key == "STABLE_HOSTNAME" then .value = $name
        else .
        end
    ]
    ')

echo "Creating app on App Platform..."
CREATE_OUTPUT=$(echo "$APP_SPEC" | doctl apps create --spec - --format ID --no-header 2>&1) || {
    echo "error: Failed to create app"
    echo "$CREATE_OUTPUT"
    exit 1
}

APP_ID=$(echo "$CREATE_OUTPUT" | head -1)
if [ -z "$APP_ID" ]; then
    echo "error: Failed to get app ID from creation output"
    echo "$CREATE_OUTPUT"
    exit 1
fi
echo "✓ Created app: $APP_ID"

# Output app ID for cleanup step
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "app_id=$APP_ID" >> "$GITHUB_OUTPUT"
fi

# Wait for app to be fully deployed (ACTIVE status)
echo "Waiting for app deployment (this may take several minutes)..."
DEPLOY_TIMEOUT=300  # 5 minutes
DEPLOY_START=$(date +%s)

while true; do
    ELAPSED=$(($(date +%s) - DEPLOY_START))
    APP_STATUS=$(doctl apps get "$APP_ID" --format ActiveDeployment.Phase --no-header 2>/dev/null || echo "UNKNOWN")
    echo "  [$ELAPSED s] Status: $APP_STATUS"

    case "$APP_STATUS" in
        ACTIVE)
            echo "✓ App deployed successfully"
            break
            ;;
        ERROR|CANCELED)
            echo "error: App deployment failed with status: $APP_STATUS"
            doctl apps logs "$APP_ID" --type=build 2>/dev/null | tail -50 || true
            exit 1
            ;;
    esac

    if [ $ELAPSED -ge $DEPLOY_TIMEOUT ]; then
        echo "error: Deployment timed out after ${DEPLOY_TIMEOUT}s"
        doctl apps logs "$APP_ID" --type=build 2>/dev/null | tail -50 || true
        exit 1
    fi
    sleep 10
done

# Get app info
echo ""
echo "App details:"
doctl apps get "$APP_ID" --format ID,DefaultIngress,ActiveDeployment.Phase 2>/dev/null || true

# Get component name for console access
COMPONENT_NAME=$(doctl apps get "$APP_ID" --format Spec.Workers[0].Name --no-header 2>/dev/null || echo "$APP_NAME")
echo "Component: $COMPONENT_NAME"

# Test app via console - verify SSH is working
echo ""
echo "Testing app via console..."

# First, figure out who we are
echo "Checking current user..."
CURRENT_USER=$(echo "whoami" | timeout 30 doctl apps console "$APP_ID" "$COMPONENT_NAME" 2>/dev/null | tr -d '\r' | tail -1) || {
    echo "error: Failed to get current user via console"
    exit 1
}
echo "✓ Console user: $CURRENT_USER"

# Check if sshd is running
echo "Checking if sshd is running..."
SSHD_CHECK=$(echo "pgrep -x sshd >/dev/null && echo SSHD_RUNNING || echo SSHD_NOT_RUNNING" | timeout 30 doctl apps console "$APP_ID" "$COMPONENT_NAME" 2>/dev/null | tr -d '\r' | tail -1) || true
if [ "$SSHD_CHECK" != "SSHD_RUNNING" ]; then
    echo "error: sshd is not running"
    exit 1
fi
echo "✓ sshd is running"

# Test SSH to different users
for target_user in ubuntu openclaw root; do
    echo "Testing SSH from $CURRENT_USER to $target_user@localhost..."
    SSH_OUTPUT=$(echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes $target_user@localhost 'whoami && motd' 2>/dev/null || echo SSH_FAILED" | timeout 30 doctl apps console "$APP_ID" "$COMPONENT_NAME" 2>/dev/null | tr -d '\r') || SSH_OUTPUT="SSH_FAILED"

    # First line should be the username
    SSH_USER=$(echo "$SSH_OUTPUT" | head -1)
    if [ "$SSH_USER" = "$target_user" ]; then
        echo "✓ SSH to $target_user@localhost works"
        echo "$SSH_OUTPUT" | tail -n +2 | head -20
    else
        echo "error: SSH to $target_user@localhost failed (got: $SSH_USER)"
        echo "$SSH_OUTPUT"
        exit 1
    fi
done

# Check logs for successful startup
echo ""
echo "Checking app logs..."
doctl apps logs "$APP_ID" --type=run 2>/dev/null | grep -E "(sshd|SSH|Started)" | tail -10 || true

echo ""
echo "App Platform deployment test passed (app will be cleaned up)"
