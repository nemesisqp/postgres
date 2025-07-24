#!/bin/sh
set -e

# Create config file for pgbackrest
# Default config path if not set. This should match the path in the Dockerfile.
PGBACKREST_CONFIG=${PGBACKREST_CONFIG:-/etc/pgbackrest/pgbackrest.conf}

# The pgBackRest configuration needs to be shared by all containers.
# We create the directory and set secure permissions.
umask 0077
mkdir -p "$(dirname "${PGBACKREST_CONFIG}")"

# Write the base configuration that is common to both local and S3 setups.
cat > "${PGBACKREST_CONFIG}" <<__EOT__
[global]
spool-path=/pgbackrest/spool

# Force a checkpoint to start backup immediately.
start-fast=y
# Use delta restore.
delta=y
expire-auto=y
# Enable async archiving for better performance.
archive-async=y
process-max=4

# Enable ZSTD compression.
compress-type=zst
compress-level=6

log-level-console=info
log-level-file=detail

repo1-retention-full=13
repo1-path=/pgbackrest/repo
__EOT__

# Conditionally add repository configuration based on environment variables.
if [ -n "${PGBR_S3_ENDPOINT}" ]; then
    echo "S3 endpoint detected. Configuring pgBackRest for S3."
    # Validate that all required S3 variables are set.
    [ -z "${PGBR_S3_KEY}" ] && { echo "ERROR: PGBR_S3_KEY is not set for S3 backup." >&2; exit 1; }
    [ -z "${PGBR_S3_BUCKET}" ] && { echo "ERROR: PGBR_S3_BUCKET is not set for S3 backup." >&2; exit 1; }
    [ -z "${PGBR_S3_KEY_SECRET}" ] && { echo "ERROR: PGBR_S3_KEY_SECRET is not set for S3 backup." >&2; exit 1; }
    # Append S3-specific repository configuration.
    cat >> "${PGBACKREST_CONFIG}" <<__EOT__
repo1-type=s3
# Define the repo path within our consolidated volume.
repo1-s3-uri-style=path
repo1-s3-region=${PGBR_S3_REGION:-us-east-1}
repo1-s3-endpoint=${PGBR_S3_ENDPOINT}
repo1-s3-bucket=${PGBR_S3_BUCKET}
repo1-s3-key=${PGBR_S3_KEY}
repo1-s3-key-secret=${PGBR_S3_KEY_SECRET}
__EOT__

else
    echo "No S3 endpoint detected. Configuring pgBackRest for local disk backup."
    # Append local repository configuration.
    cat >> "${PGBACKREST_CONFIG}" <<__EOT__
repo1-type=posix
__EOT__
fi

# Define the 'default' stanza. It will inherit pg1-path from the [global] section.
cat >> "${PGBACKREST_CONFIG}" <<__EOT__

[default]
pg1-path=/var/lib/postgresql/data
__EOT__

# Create the cron file for supercronic with the desired backup schedule.
# This is done here, as root, before supercronic starts.

PGBACKREST_CRON_FULL="${PGBACKREST_CRON_FULL:-5 2 * * 0}"
PGBACKREST_CRON_INCR="${PGBACKREST_CRON_INCR:-5 2 * * 1-6}"
CRON_FILE="/etc/cron.d/pgbackrest"
echo "Creating cron file at ${CRON_FILE} for scheduled backups..."
cat > "${CRON_FILE}" <<__EOF__
# Run a full backup every Sunday at 2:05 AM
${PGBACKREST_CRON_FULL} su - postgres -c "pgbackrest --stanza=default --type=full backup --log-level-console=info"

# Run an incremental backup every day (Mon-Sat) at 2:05 AM
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
