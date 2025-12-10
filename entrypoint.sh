#!/bin/bash
set -e

# Fix ownership of mounted volume to match the user who runs cron jobs
chown -R user:user /wd 2>/dev/null || true

# Execute the main command
exec "$@"
