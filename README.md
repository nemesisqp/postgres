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