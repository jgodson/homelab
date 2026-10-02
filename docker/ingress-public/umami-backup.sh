#!/bin/sh
# Nightly Umami database backup -> MinIO (k8s-app-backups/umami), 7 day retention.
# MinIO is replicated to Google Drive by the rclone-sync job on the MinIO host.
# Cron: 15 4 * * * /home/manager/umami-backup.sh >> /home/manager/umami-backup.log 2>&1
# Needs /home/manager/umami-backup.env (chmod 600) with RCLONE_CONFIG_BACKUP_* settings.
set -eu

DIR=/home/manager
DEST=backup:k8s-app-backups/umami
# Not /tmp: the snap-packaged docker cannot bind-mount it
TMP="$(mktemp -d -p "$DIR")"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

trap 'rm -rf "$TMP"' EXIT

docker exec umami-db sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$TMP/umami.sql.gz"
test -s "$TMP/umami.sql.gz"

docker run --rm --env-file "$DIR/umami-backup.env" -v "$TMP":/out:ro rclone/rclone:latest \
  copyto /out/umami.sql.gz "$DEST/umami-$STAMP.sql.gz"
docker run --rm --env-file "$DIR/umami-backup.env" rclone/rclone:latest \
  delete --min-age 7d "$DEST"
echo "$(date -u) backup ok: umami-$STAMP.sql.gz"
