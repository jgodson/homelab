### VM Config
- CPU: 4 Cores
- RAM: 8 GB
- Disk: 512 GB
- OS: Ubuntu server

### To get running

Create the required directories to store data for minio.

`mkdir -p minio/data minio/config minio/secrets`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp ./docker-compose.yml $USER@$IP_ADDR:~/minio`

Create the secret files. This is in `Minio` in 1Password.
```bash
echo -n "manager" > minio/secrets/root_user.txt
echo -n "<password_from_1password>" > minio/secrets/root_password.txt

chmod 600 minio/secrets/minio_root_user.txt minio/secrets/minio_root_password.txt
```

**DNS Configuration**
- Configure system DNS to use 192.168.1.253 in `/etc/systemd/resolved.conf`:
```bash
[Resolve]
DNS=192.168.1.253
Domains=~home.jasongodson.com
FallbackDNS=1.1.1.1
```
- Restart systemd-resolved: `sudo systemctl restart systemd-resolved`

Start the service

`cd minio && docker compose up -d`

### Next steps
- Login at <ip>:9001 with root user credentials
- Under Identity -> Users -> Create User, create a user `loki` (1Password `Minio`) with `readwrite` permissions to access these buckets
- Create buckets for Loki under `Buckets`: `chunks`, `ruler`, and `admin`