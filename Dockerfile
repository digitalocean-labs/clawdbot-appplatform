FROM node:22-slim

# Install Litestream for SQLite backup/restore (multi-arch)
ARG TARGETARCH
RUN apt-get update && apt-get install -y wget ca-certificates git \
    && LITESTREAM_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && wget https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-${LITESTREAM_ARCH}.deb \
    && dpkg -i litestream-v0.3.13-linux-${LITESTREAM_ARCH}.deb \
    && rm litestream-v0.3.13-linux-${LITESTREAM_ARCH}.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Clawdbot globally
RUN npm install -g clawdbot@latest

# Create data directory
RUN mkdir -p /data/.clawdbot /data/workspace

COPY entrypoint.sh /entrypoint.sh
COPY litestream.yml /etc/litestream.yml
RUN chmod +x /entrypoint.sh

ENV PORT=8080
ENV CLAWDBOT_STATE_DIR=/data/.clawdbot
ENV CLAWDBOT_WORKSPACE_DIR=/data/workspace

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
