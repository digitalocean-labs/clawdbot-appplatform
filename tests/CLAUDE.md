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
- Tests each config in `example_configs/*.env` in parallel
- Per-config test scripts in `tests/<config>/test.sh`
- Shared utilities in `tests/lib.sh` (wait_for_container, assert_service_up/down, etc.)

## Writing Tests

- Add new configs to `example_configs/<name>.env` with `STABLE_HOSTNAME=<name>`
- Create `tests/<name>/test.sh` for config-specific assertions
- Use shared helpers from `lib.sh`: `wait_for_container`, `wait_for_service`, `assert_process_running`, `assert_service_up`, `assert_service_down`

## s6 Service Checks

- `/command/s6-svok /run/service/<name>` - returns 0 if service is supervised
- `/command/s6-svstat /run/service/<name>` - shows "up" or "down" state
- Services may exist but be down - check both directory and status
