# MinIO Object Storage

## Overview
MinIO provides S3-compatible object storage used in the homelab for backup storage and as a backend for other services like Loki.

## System Requirements

### Hardware Recommendations
- **CPU**: 4 Cores
- **RAM**: 8 GB
- **Disk**: 512 GB
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- DNS resolution for local domain (optional)

## Installation

### 1. Prepare the Environment

Create the required directories for MinIO:
```bash
mkdir -p minio/data minio/config minio/secrets
```

### 2. Configuration

Copy the Docker Compose file to your server:
```bash
scp ./docker-compose.yml user@your-server-ip:~/
```

Create the secret files (I store these in 1Password):
```bash
echo -n "manager" > minio/secrets/root_user.txt
echo -n "<password_from_1password>" > minio/secrets/root_password.txt

chmod 600 minio/secrets/root_user.txt minio/secrets/root_password.txt
```

### 3. DNS Configuration (Optional)

Configure local DNS resolution in `/etc/systemd/resolved.conf`:
```bash
[Resolve]
DNS=192.168.1.253
Domains=~home.example.com
FallbackDNS=1.1.1.1
```

Restart systemd-resolved:
```bash
sudo systemctl restart systemd-resolved
```

### 4. Deployment

Start the service:
```bash
docker compose up -d
```

## Post-Installation Setup

1. Access the MinIO Console at http://your-server-ip:9001
2. Log in with the root user credentials
3. Create a new user:
   - Go to Identity -> Users -> Create User
   - Create a user `loki` with `readwrite` permissions
4. Create the following buckets for Loki:
   - `chunks`
   - `ruler`
   - `admin`

## Maintenance

### Backups
MinIO data is stored in the `minio/data` directory. Consider setting up regular backups of this directory.

### Updates
To update MinIO:
```bash
cd minio
docker compose pull
docker compose up -d
```

## Troubleshooting

- If the console is inaccessible, check:
  - Docker container status: `docker ps`
  - Container logs: `docker compose logs minio`
  - Network connectivity to the MinIO port

## References
- [MinIO Documentation](https://min.io/docs/minio/container/index.html)