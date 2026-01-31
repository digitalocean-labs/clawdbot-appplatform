# Contributing

## Testing

This project uses a matrix-based CI system that automatically tests multiple configuration combinations.

### How Tests Work

The CI workflow (`.github/workflows/test.yml`) runs in two stages:

1. **Discovery**: Scans `example_configs/` for `.env` files
2. **Matrix Build**: Runs a parallel Docker build + verification for each config

Each test:
- Builds the Docker image
- Starts the container with the specific configuration
- Waits for services to initialize
- Verifies the container is running
- Checks that expected services are active based on the config
- Collects logs and diagnostics on failure

### Adding a New Test Configuration

1. Create a new `.env` file in `example_configs/`:

```bash
# example_configs/my-new-config.env

# Description comment explaining what this tests
TAILSCALE_ENABLE=false
ENABLE_NGROK=false
ENABLE_SPACES=false
SSH_ENABLE=false
ENABLE_UI=true
STABLE_HOSTNAME=moltbot-test
S6_BEHAVIOUR_IF_STAGE2_FAILS=0
```

2. The workflow will automatically pick it up on the next CI run.

### Configuration Options

| Variable | Values | Description |
|----------|--------|-------------|
| `TAILSCALE_ENABLE` | `true`/`false` | Enable Tailscale networking |
| `ENABLE_NGROK` | `true`/`false` | Enable ngrok tunnel |
| `ENABLE_SPACES` | `true`/`false` | Enable DO Spaces backup |
| `SSH_ENABLE` | `true`/`false` | Enable SSH server |
| `ENABLE_UI` | `true`/`false` | Enable web UI |
| `STABLE_HOSTNAME` | string | Container hostname |
| `S6_BEHAVIOUR_IF_STAGE2_FAILS` | `0`/`1`/`2` | s6 failure behavior (0=continue) |

### Service Verification

The CI automatically verifies services based on your config:

- `moltbot` - Always checked (core service)
- `sshd` - Checked when `SSH_ENABLE=true`

To add verification for other services, update the "Verify expected services" step in `.github/workflows/test.yml`.

### Running Tests Locally

```bash
# Test a specific configuration
cp example_configs/minimal.env .env
make rebuild
make logs

# Check services
docker exec moltbot-test ps aux

# Clean up
docker compose down
```

### Existing Test Configurations

| File | Purpose |
|------|---------|
| `minimal.env` | Base container, all features disabled |
| `ssh-enabled.env` | SSH service with test key |
| `ui-disabled.env` | CLI-only mode |
| `ssh-and-ui.env` | Multiple services together |
| `all-optional-disabled.env` | All features explicitly false |
