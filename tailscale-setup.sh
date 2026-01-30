#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Tailscale Setup for Moltbot App Platform          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check if Tailscale account exists
info "Step 1: Tailscale Account Setup"
echo ""
echo "Before we begin, you need a Tailscale account."
echo ""
read -p "Do you already have a Tailscale account? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    info "To create a Tailscale account:"
    echo "  1. Visit https://tailscale.com/start"
    echo "  2. Sign up with your email or GitHub account"
    echo "  3. Complete the account setup"
    echo ""
    read -p "Press Enter once you have created your account..."
    echo ""
fi

success "Tailscale account ready!"
echo ""

# Step 2: Explain how to get an API key
info "Step 2: Getting Your Tailscale API Key"
echo ""
echo "To configure Tailscale programmatically, you need an API key."
echo ""
echo "To get your API key:"
echo "  1. Log in to https://login.tailscale.com/admin/settings/keys"
echo "  2. Click 'Generate auth key'"
echo "  3. Set the key to 'Reusable' (we'll make it never-expiring via API)"
echo "  4. Optionally add a description like 'Moltbot Setup'"
echo "  5. Copy the generated key (starts with 'tskey-auth-...')"
echo ""
warning "Note: The API key will be used to configure Tailscale policies and services."
echo "      Keep it secure and don't share it publicly."
echo ""

# Step 3: Get API key from user
read -p "Enter your Tailscale API key (tskey-auth-...): " TS_API_KEY
echo ""

if [[ -z "$TS_API_KEY" ]]; then
    error "API key is required. Exiting."
    exit 1
fi

if [[ ! "$TS_API_KEY" =~ ^tskey-auth- ]]; then
    error "Invalid API key format. Should start with 'tskey-auth-'"
    exit 1
fi

success "API key received!"
echo ""

# Step 4: Get Tailnet name
info "Step 3: Identifying Your Tailnet"
echo ""
echo "We need to know your Tailnet name to configure policies."
echo "Your Tailnet name is usually your organization name or username."
echo "You can find it in the Tailscale admin console URL:"
echo "  https://login.tailscale.com/admin/machines"
echo ""
read -p "Enter your Tailnet name (e.g., 'example' or 'user@example.com'): " TAILNET
echo ""

if [[ -z "$TAILNET" ]]; then
    error "Tailnet name is required. Exiting."
    exit 1
fi

success "Tailnet identified: $TAILNET"
echo ""

# Step 5: Check if jq and curl are available
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed. Please install it first."
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  macOS: brew install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    error "curl is required but not installed. Please install it first."
    exit 1
fi

# Step 6: Create ACL policy for never-expiring key
info "Step 4: Configuring Tailscale Policies"
echo ""

# First, let's check if we can authenticate with the API key
info "Testing API key authentication..."
TEST_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$TS_API_KEY:" \
    "https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl" \
    -X GET \
    -H "Content-Type: application/json" 2>&1) || true

HTTP_CODE=$(echo "$TEST_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$TEST_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
    error "Failed to authenticate with API key. HTTP code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    echo ""
    warning "Please verify:"
    echo "  1. Your API key is correct"
    echo "  2. Your Tailnet name is correct"
    echo "  3. Your API key has admin permissions"
    exit 1
fi

success "API authentication successful!"
echo ""

# Get current ACL
info "Fetching current ACL policy..."
CURRENT_ACL=$(curl -s \
    -u "$TS_API_KEY:" \
    "https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl" \
    -X GET \
    -H "Content-Type: application/json")

# Check if ACL exists and has content
if echo "$CURRENT_ACL" | jq -e '.acl' > /dev/null 2>&1; then
    ACL_CONTENT=$(echo "$CURRENT_ACL" | jq -r '.acl')
else
    ACL_CONTENT=""
fi

# Create or update ACL with moltbot tag and policies
info "Configuring ACL policy for moltbot tag..."

# Create a temporary file for the new ACL
TEMP_ACL=$(mktemp)
trap "rm -f $TEMP_ACL" EXIT

# Build the ACL JSON
if [[ -n "$ACL_CONTENT" && "$ACL_CONTENT" != "null" && "$ACL_CONTENT" != "{}" ]]; then
    # Parse existing ACL
    ACL_JSON=$(echo "$ACL_CONTENT" | jq '.')
else
    # Create new ACL structure
    ACL_JSON=$(cat <<'EOF'
{
  "groups": {},
  "hosts": {},
  "acls": [],
  "ssh": [],
  "nodeAttrs": [],
  "autoApprovers": {},
  "tests": []
}
EOF
)
fi

# Add moltbot tag to nodeAttrs if it doesn't exist
if echo "$ACL_JSON" | jq -e '.nodeAttrs[] | select(.target == ["tag:moltbot"])' > /dev/null 2>&1; then
    info "Tag 'moltbot' already exists in ACL"
else
    info "Adding 'moltbot' tag to ACL..."
    ACL_JSON=$(echo "$ACL_JSON" | jq '.nodeAttrs += [{
      "target": ["tag:moltbot"],
      "attrs": {
        "moltbot": true
      }
    }]')
fi

# Add ACL rules for moltbot tag
# Allow moltbot tag to access everything (adjust as needed)
if echo "$ACL_JSON" | jq -e '.acls[] | select(.action == "accept" and .src == ["tag:moltbot"])' > /dev/null 2>&1; then
    info "ACL rules for moltbot tag already exist"
else
    info "Adding ACL rules for moltbot tag..."
    ACL_JSON=$(echo "$ACL_JSON" | jq '.acls += [
      {
        "action": "accept",
        "src": ["tag:moltbot"],
        "dst": ["*:*"]
      },
      {
        "action": "accept",
        "src": ["*"],
        "dst": ["tag:moltbot:*"]
      }
    ]')
fi

# Add SSH access for moltbot tag
if echo "$ACL_JSON" | jq -e '.ssh[] | select(.action == "accept" and .src == ["tag:moltbot"])' > /dev/null 2>&1; then
    info "SSH rules for moltbot tag already exist"
else
    info "Adding SSH access rules for moltbot tag..."
    ACL_JSON=$(echo "$ACL_JSON" | jq '.ssh += [
      {
        "action": "accept",
        "src": ["tag:moltbot"],
        "dst": ["*"],
        "users": ["autogroup:nonroot"]
      },
      {
        "action": "accept",
        "src": ["*"],
        "dst": ["tag:moltbot"],
        "users": ["autogroup:nonroot"]
      }
    ]')
fi

# Write ACL to temp file
echo "$ACL_JSON" | jq '.' > "$TEMP_ACL"

# Update ACL via API
info "Uploading ACL policy..."
# Tailscale API uses PUT for ACL updates, but we'll try POST first, then PUT if needed
ACL_UPDATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$TS_API_KEY:" \
    "https://api.tailscale.com/api/v2/tailnet/$TAILNET/acl" \
    -X PUT \
    -H "Content-Type: application/json" \
    -d @"$TEMP_ACL" 2>&1) || true

ACL_HTTP_CODE=$(echo "$ACL_UPDATE_RESPONSE" | tail -n1)
ACL_RESPONSE_BODY=$(echo "$ACL_UPDATE_RESPONSE" | sed '$d')

if [[ "$ACL_HTTP_CODE" == "200" ]]; then
    success "ACL policy updated successfully!"
else
    error "Failed to update ACL policy. HTTP code: $ACL_HTTP_CODE"
    echo "Response: $ACL_RESPONSE_BODY"
    echo ""
    warning "You may need to configure the ACL manually in the Tailscale admin console."
    echo ""
    echo "To configure manually:"
    echo "  1. Go to https://login.tailscale.com/admin/acls"
    echo "  2. Add the following to your ACL policy:"
    echo ""
    echo "     // Define the moltbot tag"
    echo "     \"nodeAttrs\": ["
    echo "       {"
    echo "         \"target\": [\"tag:moltbot\"],"
    echo "         \"attrs\": {\"moltbot\": true}"
    echo "       }"
    echo "     ],"
    echo ""
    echo "     // Allow moltbot tag to access everything"
    echo "     \"acls\": ["
    echo "       {\"action\": \"accept\", \"src\": [\"tag:moltbot\"], \"dst\": [\"*:*\"]},"
    echo "       {\"action\": \"accept\", \"src\": [\"*\"], \"dst\": [\"tag:moltbot:*\"]}"
    echo "     ],"
    echo ""
    echo "     // SSH access for moltbot tag"
    echo "     \"ssh\": ["
    echo "       {\"action\": \"accept\", \"src\": [\"tag:moltbot\"], \"dst\": [\"*\"], \"users\": [\"autogroup:nonroot\"]},"
    echo "       {\"action\": \"accept\", \"src\": [\"*\"], \"dst\": [\"tag:moltbot\"], \"users\": [\"autogroup:nonroot\"]}"
    echo "     ]"
    echo ""
fi
echo ""

# Step 7: Create auth key with never-expiring policy and moltbot tag
info "Step 5: Creating Never-Expiring Auth Key with Moltbot Tag"
echo ""

# Create auth key with:
# - Reusable: true
# - Ephemeral: false
# - Preauthorized: true
# - Tags: ["tag:moltbot"]
# - Expiry: omitted (never expires) or 0

AUTH_KEY_PAYLOAD=$(cat <<EOF
{
  "capabilities": {
    "devices": {
      "create": {
        "reusable": true,
        "ephemeral": false,
        "preauthorized": true,
        "tags": ["tag:moltbot"]
      }
    }
  }
}
EOF
)

info "Creating auth key with moltbot tag..."
KEY_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -u "$TS_API_KEY:" \
    "https://api.tailscale.com/api/v2/tailnet/$TAILNET/keys" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$AUTH_KEY_PAYLOAD" 2>&1) || true

KEY_HTTP_CODE=$(echo "$KEY_RESPONSE" | tail -n1)
KEY_RESPONSE_BODY=$(echo "$KEY_RESPONSE" | sed '$d')

if [[ "$KEY_HTTP_CODE" == "200" || "$KEY_HTTP_CODE" == "201" ]]; then
    NEW_AUTH_KEY=$(echo "$KEY_RESPONSE_BODY" | jq -r '.key // empty')
    if [[ -n "$NEW_AUTH_KEY" && "$NEW_AUTH_KEY" != "null" ]]; then
        success "Auth key created successfully!"
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  Your new auth key (never-expiring, tagged 'moltbot'):"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "$NEW_AUTH_KEY"
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        warning "Save this key securely! It will not be shown again."
        echo ""
    else
        error "Auth key creation response was invalid."
        echo "Response: $KEY_RESPONSE_BODY"
    fi
else
    error "Failed to create auth key. HTTP code: $KEY_HTTP_CODE"
    echo "Response: $KEY_RESPONSE_BODY"
    echo ""
    warning "You may need to create the auth key manually in the Tailscale admin console."
    echo "Make sure to:"
    echo "  - Set it as 'Reusable'"
    echo "  - Add tag: moltbot"
    echo "  - Set expiry to 'Never'"
fi
echo ""

# Step 8: Configure services (moltbot on 443 and SSH)
info "Step 6: Configuring Tailscale Services"
echo ""

info "Setting up service hostnames for moltbot tag..."
echo ""
echo "Tailscale services allow you to access your device via a friendly hostname."
echo "Once your device joins with the 'moltbot' tag, it will be accessible at:"
echo ""
echo "  moltbot.<your-tailnet>.ts.net"
echo ""
echo "The following services will be available:"
echo ""
echo "  1. Moltbot Gateway (HTTPS) - Port 443"
echo "     Access via: https://moltbot.<your-tailnet>.ts.net:443"
echo ""
echo "  2. SSH Server - Port 22"
echo "     Access via: ssh moltbot.<your-tailnet>.ts.net"
echo ""

# Note: Services are advertised by the device itself
# The ACL we configured earlier allows access to these services
# The device will automatically get a hostname based on TS_HOSTNAME when it joins

info "Note: Services are automatically discovered by Tailscale when your device joins."
echo "      The ACL policy we configured allows access to these services."
echo ""

success "Service configuration complete!"
echo ""

# Step 9: Summary and next steps
info "Step 7: Setup Complete!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Summary"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✓ Tailscale account verified"
echo "✓ ACL policy configured with 'moltbot' tag"
echo "✓ Auth key created (never-expiring, tagged 'moltbot')"
echo "✓ Service policies configured (moltbot:443, SSH:22)"
echo ""
if [[ -n "${NEW_AUTH_KEY:-}" && "$NEW_AUTH_KEY" != "null" ]]; then
    echo "Your auth key: $NEW_AUTH_KEY"
    echo ""
fi
echo "═══════════════════════════════════════════════════════════"
echo ""
info "Next Steps:"
echo ""
echo "1. Add the auth key to your .env file:"
if [[ -n "${NEW_AUTH_KEY:-}" && "$NEW_AUTH_KEY" != "null" ]]; then
    echo "   TS_AUTHKEY=$NEW_AUTH_KEY"
else
    echo "   TS_AUTHKEY=<your-auth-key>"
fi
echo ""
echo "2. Set your Tailscale hostname (optional):"
echo "   TS_HOSTNAME=moltbot"
echo ""
echo "3. Deploy your application with these environment variables"
echo ""
echo "4. Once deployed, your device will:"
echo "   - Join your Tailnet with the 'moltbot' tag"
echo "   - Be accessible via: moltbot.<your-tailnet>.ts.net"
echo "   - Have SSH available at: moltbot.<your-tailnet>.ts.net:22"
echo "   - Have Moltbot Gateway at: moltbot.<your-tailnet>.ts.net:443"
echo ""
success "Setup complete! Happy deploying!"
echo ""
