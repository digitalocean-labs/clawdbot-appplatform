#!/bin/bash
# Rebuild and restart the moltbot container

set -e

CONTAINER_NAME="${CONTAINER_NAME:-moltbot-test}"
IMAGE_NAME="${IMAGE_NAME:-moltbot-test}"
PLATFORM="${PLATFORM:-linux/amd64}"

echo "=== Stopping and removing container ==="
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

echo ""
echo "=== Building image ==="
docker build --platform "$PLATFORM" -t "$IMAGE_NAME" .

echo ""
echo "=== Starting container ==="
docker run -d --name "$CONTAINER_NAME" --env-file .env "$IMAGE_NAME"

echo ""
echo "=== Container started ==="
docker ps | grep "$CONTAINER_NAME"
