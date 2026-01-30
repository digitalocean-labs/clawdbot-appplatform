# Source .bashrc if it exists (for bash-specific configurations)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && . "$HOME/.zshrc"

# Load Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

# nvm is loaded via NVM_DIR in service scripts (see /etc/services.d/moltbot/run)

# Setup pnpm PATH
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Add .local/bin to PATH if it exists
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
