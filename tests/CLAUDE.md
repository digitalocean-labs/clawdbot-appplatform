# Testing

## Running Tests

```bash
make test CONFIG=minimal   # Build, start, and test a specific config
make test-all              # Run all configs in example_configs/
make logs                  # Follow container logs
make shell                 # Shell into container
```

## How It Works

CI runs a matrix of test configurations via GitHub Actions (`.github/workflows/test.yml`):

- Builds Docker image once with layer caching
- Discovers all `.sh` scripts in each `tests/<config>/` directory
- Each `{config, script}` pair runs as an independent parallel job
- Scripts are sorted alphabetically and executed in order locally
- Shared utilities in `tests/lib.sh` (wait_for_container, assert_service_up/down, etc.)

## Writing Tests

- Add new configs to `example_configs/<name>.env` with `STABLE_HOSTNAME=<name>`
- Create test scripts in `tests/<name>/` (e.g., `test.sh`, `01-basic.sh`, `02-advanced.sh`)
- Scripts must be executable (`chmod +x`) and end with `.sh`
- Scripts are sorted alphabetically - use numeric prefixes for ordering (e.g., `01-`, `02-`)
- Each script receives the container name as `$1`
- Use shared helpers from `lib.sh`: `wait_for_container`, `wait_for_service`, `assert_process_running`, `assert_service_up`, `assert_service_down`

### Test Organization

Tests are split into focused scripts for better organization and parallel CI execution:

```
tests/minimal/
├── 01-container.sh       # Container responsiveness
├── 02-gateway.sh         # OpenClaw gateway running
└── 03-ssh-disabled.sh    # SSH not running by default

tests/ssh-enabled/
├── 01-service.sh         # SSH service and port checks
├── 02-authorized-keys.sh # SSH key setup and permissions
├── 03-connectivity.sh    # Actual SSH connection test
└── 04-disable-restart.sh # Toggle SSH via env var and service restart

tests/ssh-and-ui/
├── 01-ssh.sh             # SSH running with UI
└── 02-gateway.sh         # Gateway coexists with SSH

tests/ui-disabled/
└── 01-config.sh          # UI disabled in gateway config

tests/persistence-enabled/
├── 01-service.sh         # Backup/prune services ready
└── 02-backup-restore.sh  # Full backup and restore workflow

tests/all-optional-disabled/
├── 01-ssh-disabled.sh        # SSH not running
├── 02-networking-disabled.sh # Tailscale/ngrok not running
└── 03-persistence-disabled.sh # Backup/prune not running
```

In CI, each script runs as a separate parallel job (e.g., `test (ssh-enabled, 01-service.sh)`).
Locally, scripts run sequentially in sorted order within a single container.

## s6 Service Checks

- `/command/s6-svok /run/service/<name>` - returns 0 if service is supervised
- `/command/s6-svstat /run/service/<name>` - shows "up" or "down" state
- Services may exist but be down - check both directory and status
