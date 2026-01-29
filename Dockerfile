FROM tailscale/tailscale:stable AS tailscale

FROM node:24-slim

# Copy Tailscale binaries
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/real_tailscale
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/containerboot /usr/local/bin/containerboot
COPY tailscale /usr/local/bin/tailscale

ARG TARGETARCH
ARG CLAWDBOT_VERSION=latest
ARG LITESTREAM_VERSION=0.5.6

ENV CLAWDBOT_STATE_DIR=/data/.clawdbot \
    CLAWDBOT_WORKSPACE_DIR=/data/workspace \
    TS_STATE_DIR=/data/tailscale \
    NODE_ENV=production

# Install OS deps + Litestream + s3cmd for state backup
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
      curl \
      openssl \
      jq \
      sudo \
      git \
      s3cmd \
      python3; \
    LITESTREAM_ARCH="$( [ "$TARGETARCH" = "arm64" ] && echo arm64 || echo x86_64 )"; \
    wget -O /tmp/litestream.deb \
      https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${LITESTREAM_ARCH}.deb; \
    dpkg -i /tmp/litestream.deb; \
    rm /tmp/litestream.deb; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY litestream.yml /etc/litestream.yml
COPY moltbot.default.json /etc/clawdbot/moltbot.default.json
RUN chmod +x /entrypoint.sh

# Create non-root user with sudo access (needed for some clawdbot operations)
RUN useradd -r -m -d /home/clawdbot clawdbot \
    && mkdir -p "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE_DIR}" "${TS_STATE_DIR}" \
    && chown -R clawdbot:clawdbot /data \
    && echo 'clawdbot ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/clawdbot \
    && chmod 440 /etc/sudoers.d/clawdbot

# Homebrew and pnpm paths
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
ENV PNPM_HOME="/home/clawdbot/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

# Create pnpm directory
RUN mkdir -p ${PNPM_HOME} && chown -R clawdbot:clawdbot /home/clawdbot/.local

USER clawdbot

# Install Homebrew (must run as non-root)
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install pnpm and clawdbot
RUN brew install pnpm \
    && pnpm add -g "clawdbot@${CLAWDBOT_VERSION}"

# Expose port for LAN mode
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
