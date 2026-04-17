#!/bin/sh
set -e

export PGUSER="$POSTGRES_USER"

echo "Enabling archive"
echo "archive_mode = on" >> "$PGDATA/postgresql.auto.conf"
echo "wal_level = replica" >> "$PGDATA/postgresql.auto.conf"
echo "archive_timeout = 1800s" >> "$PGDATA/postgresql.auto.conf"
echo "archive_command = 'pgbackrest --stanza=main archive-push %p'" >> "$PGDATA/postgresql.auto.conf"
echo "Archive enabled"
