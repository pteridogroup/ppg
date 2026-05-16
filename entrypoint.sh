#!/bin/bash
set -e

# Fix ownership and permissions of mounted volume to match the user who runs
# cron jobs. This ensures tar_make() can update existing files in _targets.
if [ -d /wd ]; then
  echo "Fixing ownership of /wd to user:user..."
  chown -R user:user /wd
  chmod -R u+rwX /wd
  echo "Ownership fixed."
fi

# Only start cron in background for interactive mode (bash)
# For cron mode, let 'cron -f' run in foreground via exec
if [ "$1" = "bash" ]; then
  if ! pgrep -x cron > /dev/null; then
    echo "Starting cron service for interactive mode..."
    cron
    echo "Cron started."
  fi
fi

# Execute the main command
exec "$@"
