# Homebrew (Linuxbrew) shell environment setup
# Only load if Homebrew is installed - it's optional in this image
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
