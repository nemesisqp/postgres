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

# release for git CI build
```bash
TAG="pg18-pgv0.8.2-pgvs0.9.0-pgrg4.0.6"

git add .
git commit -m "new updates, $TAG"
git tag $TAG
git push
git push origin $TAG
```

# rollback failed tag and repush
```bash
TAG="pg18-pgv0.8.2-pgvs0.9.0-pgrg4.0.6"
git push origin --delete $TAG
git tag -d $TAG
git add .
git commit -m "Hotfix for $TAG"
git tag $TAG
git push
git push origin $TAG

```
# How to from source [dataegret](https://dataegret.com/2025/12/pgbackrest-pitr-in-docker-a-simple-demo/)
## Restore the latest backup into that volume
Mount the backup repository as read-only (:ro) to avoid any accidental writes to your backups. We also disable archiving on this restored instance to prevent it from pushing WAL archives back to the production repo.
```bash
docker run --rm \
-v pg-test-restore-data:/var/lib/postgresql \
-v pgbr-repo:/var/lib/pgbackrest:ro \
nemesisqp/postgres \
pgbackrest restore --stanza=main --no-delta --log-level-console=info \
--archive-mode=off --target-timeline=current
```
Notes on the flags:
* `--no-delta` restores into an empty directory.
* `--archive-mode=off` stops the restored server from archiving WAL.
* `--target-timeline=current` asks PostgreSQL to recover along the same timeline that was current when the backup was taken.

## Start a temporary PostgreSQL container from the restored volume
We map container port 5432 to host port 5433 so it does not clash with the main container.
```bash
docker run -d \
--name pg18-pgbackrest-restored \
-e POSTGRES_PASSWORD=demo \
-p 5433:5432 \
-v pg-test-restore-data:/var/lib/postgresql \
-v pgbr-repo:/var/lib/pgbackrest:ro \
nemesisqp/postgres
```