# Moltbot App Platform Image

Pre-built Docker image for deploying [Moltbot](https://github.com/moltbot/moltbot) on DigitalOcean App Platform with Tailscale networking.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/digitalocean-labs/moltbot-appplatform/tree/main)

## Features

- **Fast boot** (~30 seconds vs 5-10 min source build)
- **Private networking** via Tailscale - secure access without public exposure
- **Optional persistence** via Litestream + DO Spaces
- **Gradient AI support** - Use DigitalOcean's serverless AI inference
- **SSH access** - Optional SSH server for remote access
- **Multi-arch** support (amd64/arm64)

## Quick Start

1. Click the **Deploy to DO** button above
2. Set required environment variables (see below)
3. Wait for deployment (~1 minute)
4. Access via `https://moltbot.<your-tailnet>.ts.net`

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     moltbot-appplatform                          │
│  ┌─────────────┐  ┌───────────┐  ┌──────────────────────────┐   │
│  │ Ubuntu      │  │ Moltbot   │  │ Litestream (optional)    │   │
│  │ Noble+Node  │  │ (latest)  │  │ SQLite → DO Spaces       │   │
│  └─────────────┘  └───────────┘  └──────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Tailscale - Private networking via tailnet (required)      ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ SSH Server (optional) - Remote access via ENABLE_SSH=true  ││
│  └─────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `TS_AUTHKEY` | Tailscale auth key for joining your tailnet |
| `SETUP_PASSWORD` | Password for the web setup wizard |

### Recommended

| Variable | Description |
|----------|-------------|
| `TS_HOSTNAME` | Hostname on your tailnet (default: container hostname) |
| `MOLTBOT_GATEWAY_TOKEN` | Admin token for gateway API access |

### Optional (SSH)

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_SSH` | Start SSH server on port 22 | `false` |

### Optional (Gradient AI)

| Variable | Description |
|----------|-------------|
| `GRADIENT_API_KEY` | DigitalOcean Gradient AI Model Access Key |

When set, adds Gradient as a model provider with access to:
- Llama 3.3 70B Instruct
- Claude 4.5 Sonnet
- Claude Opus 4.5
- DeepSeek R1 Distill Llama 70B

### Optional (Persistence)

Without these, the app runs in ephemeral mode - state is lost on redeploy.

| Variable | Description | Example |
|----------|-------------|---------|
| `LITESTREAM_ACCESS_KEY_ID` | DO Spaces access key | |
| `LITESTREAM_SECRET_ACCESS_KEY` | DO Spaces secret key | |
| `SPACES_ENDPOINT` | Spaces endpoint | `tor1.digitaloceanspaces.com` |
| `SPACES_BUCKET` | Spaces bucket name | `my-moltbot-backup` |

## Resource Requirements

| Resource | Value |
|----------|-------|
| CPU | 1 shared vCPU |
| RAM | 2 GB |
| Instance | `apps-s-1vcpu-2gb` |
| Cost | ~$25/mo (+ $5/mo Spaces optional) |

> **Note:** The gateway requires 2GB RAM to start reliably. Using `basic-xs` (1GB) will result in OOM errors.

## Available Regions

- `nyc` - New York
- `ams` - Amsterdam
- `sfo` - San Francisco
- `sgp` - Singapore
- `lon` - London
- `fra` - Frankfurt
- `blr` - Bangalore
- `syd` - Sydney
- `tor` - Toronto (default)

Edit the `region` field in `app.yaml` to change.

## Manual Deployment

```bash
# Clone and deploy
git clone https://github.com/digitalocean-labs/moltbot-appplatform
cd moltbot-appplatform

# Validate spec
doctl apps spec validate app.yaml

# Create app
doctl apps create --spec app.yaml

# Set secrets in the DO dashboard
```

## Customizing the Image

The `rootfs/` directory allows you to add or override any files in the container. Files are copied to `/` at the end of the Docker build.

### Examples

```
rootfs/
├── etc/
│   ├── ssh/
│   │   └── sshd_config.d/
│   │       └── 10-custom.conf     → /etc/ssh/sshd_config.d/10-custom.conf
│   └── motd                        → /etc/motd
└── home/
    └── moltbot/
        └── .bashrc                 → /home/moltbot/.bashrc
```

### Notes

- Files are copied with `COPY rootfs/ /` which preserves directory structure
- Existing files in the container will be overwritten
- File permissions from the source are preserved

## Setting Up Persistence

App Platform doesn't have persistent volumes, so this image uses DO Spaces for state backup.

### What Gets Persisted

| Data Type | Backup Method | Description |
|-----------|--------------|-------------|
| Memory search index | Litestream (real-time) | SQLite database for vector search |
| Config, devices, sessions | S3 backup (every 5 min) | JSON state files |
| Tailscale state | S3 backup (every 5 min) | Auth keys and node identity |

### Setup Steps

1. **Create a Spaces bucket** in the same region as your app
   - Go to **Spaces Object Storage** → **Create Bucket**
   - Name: e.g., `moltbot-backup`
   - Region: match your app (e.g., `tor1` for Toronto)

2. **Create Spaces access keys**
   - Go to **Settings → API → Spaces Keys**
   - Click **Generate New Key**
   - Save both Access Key and Secret Key

3. **Add environment variables** to your App Platform app:
   - `LITESTREAM_ACCESS_KEY_ID` = your access key
   - `LITESTREAM_SECRET_ACCESS_KEY` = your secret key
   - `SPACES_ENDPOINT` = `<region>.digitaloceanspaces.com` (e.g., `tor1.digitaloceanspaces.com`)
   - `SPACES_BUCKET` = your bucket name

4. **Redeploy** the app

### How It Works

On startup:
1. Restores JSON state backup from Spaces (if exists)
2. Restores Tailscale state from Spaces (if exists)
3. Restores SQLite memory database via Litestream (if exists)
4. Starts the gateway

During operation:
- Litestream continuously replicates SQLite changes (1s sync interval)
- JSON state and Tailscale state are backed up every 5 minutes
- On graceful shutdown (SIGTERM), final state backup is saved

## Tailscale Setup

Tailscale is required for networking. To set up:

1. Create a Tailscale auth key at https://login.tailscale.com/admin/settings/keys
2. Set `TS_AUTHKEY` environment variable
3. Optionally set `TS_HOSTNAME` for a custom hostname
4. Deploy as a **worker** (use `.do/deploy.template.yaml`)
5. Access via `https://moltbot.<your-tailnet>.ts.net`

## Documentation

- [Full deployment guide](https://docs.molt.bot/digitalocean)
- [Moltbot documentation](https://docs.molt.bot)

## License

MIT
