# Media Cloud

Docker Compose services for the `media-cloud` VM.

This starts with Jellyfin only. Immich and Nextcloud should be added after the base storage and deployment path are proven.

## Layout

- `/opt/homelab/docker/media-cloud` - compose files, cloned from this repo by automation
- `/mnt/storage/media` - media library, mounted read-only into Jellyfin
- `/mnt/storage/jellyfin` - Jellyfin config and cache
- `/mnt/storage/immich` - reserved for Immich
- `/mnt/storage/nextcloud-data` - reserved for Nextcloud

## First Run

On `media-cloud`:

```bash
cd /opt/homelab/docker/media-cloud
cp .env.example .env
mkdir -p /mnt/storage/jellyfin/config /mnt/storage/jellyfin/cache
sudo chown -R 1000:1000 /mnt/storage/jellyfin
sudo docker compose up -d
```

Then open:

```text
http://192.168.1.4:8096
```

## Media Uploads

Jellyfin treats `/mnt/storage/media` as read-only. Add files on the host, over SSH/SCP/rsync, or later through a dedicated share/service.

Expected media folders:

```text
/mnt/storage/media/
  movies/
  shows/
  videos/
```

After adding files, rescan the Jellyfin library from the web UI.
