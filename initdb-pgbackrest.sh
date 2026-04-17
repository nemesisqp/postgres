#!/bin/sh
set -e

# Wait for PostgreSQL to be ready before creating the stanza.
while ! pg_isready -q; do
    echo "Waiting for PostgreSQL to become available"
    sleep 3
done

echo "Creating pgBackRest stanza 'default'..."
pgbackrest stanza-create --config=${PGBACKREST_CONFIG} --stanza=default --log-level-stderr=info
echo "pgBackRest stanza created successfully."

echo "Enabling archiving..."
psql -U postgres -c "ALTER SYSTEM SET archive_mode = 'on';"
psql -U postgres -c "ALTER SYSTEM SET archive_timeout = '1800s';"
psql -U postgres -c "ALTER SYSTEM SET archive_command = 'pgbackrest --config=${PGBACKREST_CONFIG} --stanza=default --log-level-stderr=info archive-push %p';"
psql -U postgres -c "SELECT pg_reload_conf();"
echo "Archiving enabled."
