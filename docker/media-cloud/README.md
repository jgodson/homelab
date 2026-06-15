# Media Cloud

Docker Compose services for the `media-cloud` VM.

Currently included:

- Jellyfin for movies, shows, and other video files
- Immich for photo and personal video backup

## Layout

- `/opt/homelab/docker/media-cloud` - compose files, cloned from this repo by automation
- `/mnt/storage/media` - media library, mounted read-only into Jellyfin
- `/mnt/storage/share/documents` - general document/file share
- `/mnt/storage/jellyfin` - Jellyfin config and cache
- `/mnt/storage/immich/upload` - Immich uploaded assets
- `/mnt/storage/immich/postgres` - Immich Postgres data
- `/mnt/storage/immich/model-cache` - Immich machine-learning model cache
- `/mnt/storage/nextcloud-data` - reserved for Nextcloud

## First Run

The private automation repo creates the host-local `.env` file and storage directories.

Manual equivalent on `media-cloud`:

```bash
cd /opt/homelab/docker/media-cloud
cp .env.example .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$(openssl rand -hex 16)/" .env
chmod 600 .env
mkdir -p /mnt/storage/jellyfin/{config,cache}
mkdir -p /mnt/storage/immich/{upload,postgres,model-cache}
sudo chown -R 1000:1000 /mnt/storage/jellyfin /mnt/storage/immich
sudo docker compose up -d
```

Then open Jellyfin:

```text
http://192.168.1.4:8096
https://media.home.jasongodson.com
```

And Immich:

```text
http://192.168.1.4:2283
https://photos.home.jasongodson.com
```

## Media Uploads

Jellyfin treats `/mnt/storage/media` as read-only from inside the container. Add files on the host, over SSH/SCP/rsync, or through Samba.

Expected media folders:

```text
/mnt/storage/media/
  movies/
  shows/
  videos/
```

After adding files, rescan the Jellyfin library from the web UI.

## Samba Shares

The private automation repo configures Samba on `media-cloud`.

Shares:

```text
smb://192.168.1.4/documents
smb://192.168.1.4/media
```

Use the `manager` username. The Samba password is generated host-locally by automation.
