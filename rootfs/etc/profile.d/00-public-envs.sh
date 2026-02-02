# Load PUBLIC_ environment variables for all users
# These are world-readable settings broadcast to all prefix directories
if [ -f /etc/s6-overlay/lib/env-utils.sh ]; then
  . /etc/s6-overlay/lib/env-utils.sh
  source_env_prefix PUBLIC_
fi
