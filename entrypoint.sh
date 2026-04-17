#!/bin/sh
set -e

# Create the cron file for supercronic with the desired backup schedule.
# This is done here, as root, before supercronic starts.

# Schedule for FULL backups. 
# Default: "5 2 * * 0" -> Runs at 02:05 AM every Sunday (Day 0).
PGBACKREST_CRON_FULL="${PGBACKREST_CRON_FULL:-5 2 * * 0}"

# Schedule for INCREMENTAL backups. 
# Default: "5 2 * * 1-6" -> Runs at 02:05 AM every Monday through Saturday (Days 1-6).
PGBACKREST_CRON_INCR="${PGBACKREST_CRON_INCR:-5 2 * * 1-6}"

CRON_FILE="/etc/cron.d/pgbackrest"
# Ensure the parent directory exists
mkdir -p "$(dirname "${CRON_FILE}")"
echo "Creating cron file at ${CRON_FILE} for scheduled backups..."
cat > "${CRON_FILE}" <<__EOF__
# Run a full backup
${PGBACKREST_CRON_FULL} su - postgres -c "pgbackrest --stanza=default --type=full backup --log-level-console=info"

# Run an incremental backup
${PGBACKREST_CRON_INCR} su - postgres -c "pgbackrest --stanza=default --type=incr backup --log-level-console=info"
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
