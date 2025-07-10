# postgres
Postgresql, postgis, pgvector, pgvectorscale, pgroonga, cron, safeupdate

# build command
```bash
docker buildx build --push --platform linux/arm64,linux/amd64 --tag nemesisqp/postgres:pg17-pgv0.8.0-pgvs0.8.0-pgrg4.0.1 --tag nemesisqp/postgres:latest .
```
