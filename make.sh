#!/bin/bash

# Script to run targets::tar_make() from inside Docker container

# Set working directory
cd /wd || exit 1

# Log date and time
echo "Run started at $(date)" >> /wd/cron-log.txt

# Run the pipeline and capture output + errors
/usr/local/bin/Rscript -e "targets::tar_make()" >> /wd/cron-log.txt 2>&1

echo "Run finished at $(date)" >> /wd/cron-log.txt