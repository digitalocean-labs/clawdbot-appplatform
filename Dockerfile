FROM tailscale/tailscale:stable AS tailscale


FROM node:24-slim

COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/real_tailscale
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/containerboot /usr/local/bin/containerboot

COPY tailscale /usr/local/bin/tailscale

ARG TARGETARCH=x86_64
ARG CLAWDBOT_VERSION=latest
ARG LITESTREAM_VERSION=0.5.6

ENV CLAWDBOT_STATE_DIR=/data/.clawdbot \
    CLAWDBOT_WORKSPACE_DIR=/data/workspace \
    NODE_ENV=production

# Install OS deps + Litestream + s3cmd for state backup
# Note: Litestream 0.5.x uses x86_64 (not amd64) and no 'v' prefix in filename
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    vim \
    jq \
    curl \
    openssl \
    sudo \
    procps \
    build-essential \
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
RUN chmod +x /entrypoint.sh

# Create non-root user with home directory, add to sudoers (NOPASSWD)
RUN useradd -r -m -d /home/clawdbot clawdbot \
    && mkdir -p "${CLAWDBOT_STATE_DIR}" && mkdir -p "${CLAWDBOT_WORKSPACE_DIR}" \
    && chown -R clawdbot:clawdbot /data "${CLAWDBOT_STATE_DIR}" "${CLAWDBOT_WORKSPACE_DIR}" \
    && echo 'clawdbot ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/clawdbot \
    && chmod 440 /etc/sudoers.d/clawdbot



# Add Homebrew and pnpm to PATH
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
ENV PNPM_HOME="/home/clawdbot/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

# Create pnpm global bin directory with correct ownership
RUN mkdir -p ${PNPM_HOME} && chown -R clawdbot:clawdbot /home/clawdbot/.local

# Switch to clawdbot for Homebrew install (must run as non-root)
USER clawdbot

# Install Homebrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install pnpm via Homebrew and clawdbot globally
RUN NONINTERACTIVE=1 brew install pnpm \
    && pnpm add -g "clawdbot@${CLAWDBOT_VERSION}" 

ENTRYPOINT ["/entrypoint.sh"]
