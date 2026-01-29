# Moltbot App Platform Deployment

## Overview

This repository contains the Docker configuration and deployment templates for running [Moltbot](https://github.com/moltbot/moltbot) on DigitalOcean App Platform with Tailscale networking.

## Key Files

- `Dockerfile` - Builds image with Ubuntu Noble, Tailscale, Homebrew, pnpm, and moltbot
- `entrypoint.sh` - Builds config from env vars, starts Tailscale, and launches gateway
- `app.yaml` - App Platform service configuration (for reference, uses worker for Tailscale)
- `.do/deploy.template.yaml` - App Platform worker configuration (recommended)
- `litestream.yml` - SQLite replication config for persistence via DO Spaces
- `moltbot.default.json` - Base gateway configuration
- `tailscale` - Wrapper script to inject socket path for tailscale CLI
- `rootfs/` - Overlay directory for custom files

## Networking

Tailscale is required for networking. The gateway binds to loopback and uses Tailscale serve mode for access via your tailnet.

Required environment variables:
- `TS_AUTHKEY` - Tailscale auth key

## Configuration

All gateway settings are driven by the config file (`moltbot.json`). The entrypoint dynamically builds the config based on environment variables:

- Tailscale serve mode for networking
- Gradient AI provider (if `GRADIENT_API_KEY` set)

## Gradient AI Integration

Set `GRADIENT_API_KEY` to enable DigitalOcean's serverless AI inference with models:
- Llama 3.3 70B Instruct
- Claude 4.5 Sonnet / Opus 4.5
- DeepSeek R1 Distill Llama 70B

## Persistence

Optional DO Spaces backup via Litestream + s3cmd:
- SQLite: real-time replication via Litestream
- JSON state: periodic backup every 5 minutes
- Tailscale state: periodic backup every 5 minutes
