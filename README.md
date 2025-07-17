# postgres
Postgresql
* postgis
* pgvector
* pgvectorscale
* pgroonga
* pg_cron
* pg_safeupdate
* pgbackrest with full backup per week, daily incremental backup, keep for 3 months

# build command
```bash
docker buildx build --push --platform linux/arm64,linux/amd64 --tag nemesisqp/postgres:pg17-pgv0.8.0-pgvs0.8.0-pgrg4.0.1 --tag nemesisqp/postgres:latest .
```

# image url
* `ghcr.io/nemesisqp/postgres:latest`
