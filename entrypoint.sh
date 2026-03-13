#!/bin/bash
set -e

# Fix ownership of mounted volume to match the user who runs cron jobs
# This ensures files created by cron jobs have the correct ownership
if [ -d /wd ]; then
  echo "Fixing ownership of /wd to user:user..."
  chown -R user:user /wd
  echo "Ownership fixed."
fi

# Execute the main command
exec "$@"
