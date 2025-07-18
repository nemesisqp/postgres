#!/bin/sh
set -e

# Create the cron file for supercronic with the desired backup schedule.
# This is done here, as root, before supercronic starts.
CRON_FILE="/etc/cron.d/pgbackrest"
echo "Creating cron file at ${CRON_FILE} for scheduled backups..."
cat > "${CRON_FILE}" <<__EOF__
# Run a full backup every Sunday at 2:05 AM
5 2 * * 0 pgbackrest --stanza=default --type=full backup --log-level-console=info

# Run an incremental backup every day (Mon-Sat) at 2:05 AM
5 2 * * 1-6 pgbackrest --stanza=default --type=incr backup --log-level-console=info
__EOF__
chmod 0644 "${CRON_FILE}"

# Start supercronic in the background, pointing to our newly created file.
echo "Starting supercronic scheduler in the background..."
/usr/local/bin/supercronic "${CRON_FILE}" &

# Execute the original postgres entrypoint.
# 'exec' is important to replace the shell with the postgres process,
# making it PID 1 and allowing it to receive signals correctly.
echo "Starting PostgreSQL..."
exec /usr/local/bin/docker-entrypoint.sh "$@"
