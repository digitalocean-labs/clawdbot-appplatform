# Source .bashrc if it exists (for bash-specific configurations)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
[ -f "$HOME/.zshrc" ] && . "$HOME/.zshrc"

# Add .local/bin to PATH if it exists
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
