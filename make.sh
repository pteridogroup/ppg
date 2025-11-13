#!/usr/bin/env bash
set -euo pipefail

# Explicit env for cron
export PATH="/usr/local/bin:/usr/bin:/bin"
# Match the non-root user’s home you created in the Dockerfile
export HOME="/home/user"

# Where your repo is mounted
WD="/wd"
LOG="/var/log/cron.log"
LOCK="/tmp/tar_make.lock"

# Sanity checks
if [ ! -d "$WD" ]; then
  echo "$(date -Is) [ERROR] Workdir $WD not found" >> "$LOG"
  exit 1
fi

cd "$WD"

# Start log
echo "$(date -Is) [INFO] Run started (uid=$(id -u) gid=$(id -g) who=$(id -un)) in $(pwd)" >> "$LOG"

# Single-run lock to avoid overlap
# If a previous run is still working, just skip this one
if ! flock -n "$LOCK" true; then
  echo "$(date -Is) [WARN] Previous run still active; skipping" >> "$LOG"
  exit 0
fi

# Run inside the lock
flock -n "$LOCK" bash -c '
  # Print a little context for debugging
  echo "$(date -Is) [INFO] R begins" >> "'"$LOG"'"
  /usr/local/bin/Rscript -e "renv::activate(); targets::tar_make()" >> "'"$LOG"'" 2>&1
' || {
  echo "$(date -Is) [ERROR] tar_make() failed" >> "$LOG"
  exit 1
}

echo "$(date -Is) [INFO] Run finished" >> "$LOG"