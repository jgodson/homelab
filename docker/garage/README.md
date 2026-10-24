# Garage Object Storage

## Overview
[Garage](https://garagehq.deuxfleurs.fr/) provides S3-compatible object storage for the homelab: backups (CNPG, Gitea, etcd, app backups, OpenTofu state) and storage for Loki and Tempo. It replaced MinIO, whose community edition is no longer maintained, on the same VM (`minio`, `192.168.1.252`), so clients still use `http://192.168.1.252:9000`.

Buckets and per-key grants are managed with OpenTofu in `homelab-automation` (`tofu/garage-buckets.tf`). Access keys are created by hand so their secrets stay out of OpenTofu state.

## Ports
- `9000`: S3 API (container port `3900`)
- `3903`: Admin API. `/health` needs no auth (Uptime Kuma); `/metrics` needs the metrics token (Prometheus); everything else needs the admin token (OpenTofu provider).

## System Requirements
- **CPU**: 4 Cores
- **RAM**: 8 GB
- **Disk**: 512 GB
    - Use `Cache: Writeback` for best performance on HDD
    - Additionally after creating run `zfs set sync=disabled rpool/data/vm-<vmid>-disk-0`
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- The Grafana Loki Docker logging plugin, installed and enabled with the
  `loki` alias. The `homelab-automation` repository manages this dependency
  and reconciles it before Garage starts after a Docker daemon restart.

## Installation

### 1. Prepare the Environment

```bash
mkdir -p ~/garage/meta ~/garage/data ~/garage/secrets ~/garage/rclone
```

Copy `docker-compose.yml` and `garage.toml` into `~/garage`.

### 2. Secrets

Generate the secrets (store them in 1Password):
```bash
cd ~/garage
umask 077
openssl rand -hex 32 > secrets/rpc_secret
openssl rand -base64 32 > secrets/admin_token
openssl rand -base64 32 > secrets/metrics_token
```

### 3. DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal adguard server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server.

### 4. Deployment

```bash
docker compose up -d
```

### 5. Cluster Layout (first start only)

```bash
alias garage='sudo docker exec garage /garage'
garage status                                   # note the node ID
garage layout assign -z homelab -c 400G <node-id>
garage layout apply --version 1
```

### 6. Keys, Buckets and Grants

Create each access key by hand; the secret is printed once:
```bash
garage key create <key-name>
```

Then add the key ID and its grants to `tofu/garage-buckets.tf` in `homelab-automation` and apply. Current keys:

| Key | Used by |
| --- | --- |
| `tofu-state` | OpenTofu state backend |
| `etcd-backup` | etcd snapshot workflow |
| `cnpg-backup-homelab` | CNPG `postgresql/postgresql-pg` |
| `cnpg-backup-spendseer` | CNPG `spendseer/spendseer-pg` |
| `gitea-backups` | Gitea data backup CronJob |
| `k8s-app-backups` | Grafana, Uptime Kuma, and Umami backups |
| `observability` | Loki and Tempo |
| `rclone-sync` | Offsite sync (read-only) |

## Offsite Backups

The `rclone-sync` service copies the backup buckets to Google Drive. Root cron runs it every 6 hours:

```cron
0 */6 * * * cd /home/manager/garage && { date; /snap/bin/docker compose --profile backup run --rm rclone-sync; date; } >> /var/log/rclone-sync.log 2>&1
```

`./rclone/rclone.conf` has a `garage` remote (`type = s3`, `provider = Other`, `endpoint = http://garage:3900`, `region = us-east-1`, `rclone-sync` key) and a `gdrive` remote (`type = drive`, set up with `docker compose --profile backup run --rm rclone-sync rclone config`).

## Maintenance

### Updates
The image is pinned to a version tag, so the Docker updates workflow won't move it. To upgrade, check the [release notes](https://git.deuxfleurs.fr/Deuxfleurs/garage/releases), bump the tag in `docker-compose.yml`, then:
```bash
cd ~/garage
docker compose up -d
```

### Useful Commands
```bash
garage status
garage bucket list
garage bucket info <bucket>
garage key list
garage key info <key-name>
```

## Troubleshooting

- Container status and logs: `docker ps`, `docker compose logs garage`
- Health: `curl http://192.168.1.252:3903/health`
- Clients must use path-style requests and region `us-east-1`
- If the Loki plugin is disabled, Docker cannot create the Garage container
  because the Compose file explicitly selects `driver: loki`. Re-enable it
  with `sudo docker plugin enable loki`, then run `docker compose up -d`.

## References
- [Garage Documentation](https://garagehq.deuxfleurs.fr/documentation/)
- [S3 compatibility](https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/)
