#!/bin/sh
set -e

export PGUSER="$POSTGRES_USER"

echo "Enabling archive"
echo "archive_mode = on" >> "$PGDATA/postgresql.auto.conf"
echo "wal_level = replica" >> "$PGDATA/postgresql.auto.conf"
echo "archive_timeout = 1800s" >> "$PGDATA/postgresql.auto.conf"
echo "archive_command = 'pgbackrest --stanza=main archive-push %p'" >> "$PGDATA/postgresql.auto.conf"
echo "Archive enabled"

until pg_isready -U postgres; do
  sleep 1
done

echo "Ensuring pgBackRest stanza 'main' exists..."

if ! pgbackrest --stanza=main info >/dev/null 2>&1; then
  echo "Creating pgBackRest stanza 'main'..."
  pgbackrest --stanza=main stanza-create --log-level-console=info
else
  echo "Stanza 'main' already exists, skipping."
fi