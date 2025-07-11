#!/bin/sh
set -e

# Start supercronic in the background.
# It will read all files in the /etc/cron.d directory.
echo "Starting supercronic scheduler in the background..."
/usr/local/bin/supercronic -passthrough-logs /etc/cron.d &

# Execute the original postgres entrypoint.
# 'exec' is important to replace the shell with the postgres process,
# making it PID 1 and allowing it to receive signals correctly.
echo "Starting PostgreSQL..."
exec /usr/local/bin/docker-entrypoint.sh "$@"
