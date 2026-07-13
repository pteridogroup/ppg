#!/bin/bash
set -e

# Fix ownership and permissions of mounted volume to match the local dev
# user. This ensures tar_make() can update existing files in _targets.
if [ -d /wd ]; then
  echo "Fixing ownership of /wd to user:user..."
  chown -R user:user /wd
  chmod -R u+rwX /wd
  echo "Ownership fixed."
fi

# Execute the main command
exec "$@"
