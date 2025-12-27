# Local Ingress + AdGuard

## Overview
This setup provides local DNS resolution, ad blocking, and reverse proxy services for the homelab environment. It combines AdGuard Home for DNS filtering and ad blocking with Caddy as a reverse proxy for internal services.

## System Requirements

### Hardware Recommendations
- **CPU**: 2 Cores
- **RAM**: 4 GB
- **Disk**: 32 GB (Shared for high availability)
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- Cloudflare account with a registered domain
- SSH access to the server

## Installation

### 1. Prepare the Environment

Create the required directories for AdGuard and Caddy:
```bash
mkdir -p adguard/work adguard/conf caddy/data caddy/config caddy/secrets
```

### 2. Configure Environment Variables

Create the environment file for Caddy:
```bash
# This file needs an API Token for Cloudflare to set DNS records
# It should have All zones - Zone:Read, DNS:Edit permissions
# Format is CF_API_TOKEN=<token>
nano caddy/.env

# Secure the environment file
chmod 600 caddy/.env
```

### 3. Deploy Application Files

Copy the necessary files to your server:
```bash
scp -r ./docker-compose.yml ./Caddy-Dockerfile ./caddy user@your-server-ip:~/
```

### 4. Deployment

Start the services:
```bash
docker compose up -d
```

## Post-Installation Setup

### AdGuard Home
1. **Initial Setup**: Access the AdGuard setup wizard at http://your-server-ip:3000
2. Follow the setup wizard to:
   - Configure DNS settings. Specifically you should point your $DOMAIN that is set in Caddy to this server's ip address.
   - Set up admin credentials
   - Configure filtering preferences
3. **After setup**: AdGuard will be available at http://adguard.home.example.com or http://your-server-ip:8080

### Caddy Reverse Proxy
- Configure using the Caddyfile located in `./caddy/Caddyfile`
- Metrics are available at http://your-server-ip:2019/metrics

#### DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal adguard server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server. Instead of a specific ip, in this case you can use `localhost`.

## Service Integration

### DNS Resolution
1. Point your network devices to use the AdGuard server (your-server-ip) as the primary DNS
2. For automatic domain resolution, configure your network DHCP to assign this DNS server

### Local Service Access
- All configured local services will be accessible through their designated subdomains
- SSL certificates are automatically managed by Caddy

## Maintenance

### Backups
Important data to back up includes:
- AdGuard configuration (`adguard/conf`)
- Caddy data and configuration (`caddy/data` and `caddy/config`)

### Updates
To update the services:
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

- **DNS Issues**: Check AdGuard logs with `docker compose logs -f adguard`
- **Reverse Proxy Issues**: Check Caddy logs with `docker compose logs -f caddy`
- **Configuration Problems**: Verify the Caddyfile syntax with `docker exec caddy caddy validate --config /etc/caddy/Caddyfile`

> [!TIP]
> To reload the Caddyfile without restarting the container, use the following command:
> ```bash
> docker exec caddy caddy reload --config /etc/caddy/Caddyfile
> ```
>
> Alternatively, you can use the provided script to update and reload the Caddyfile from your local machine:
> ```bash
> cd caddy
> ./update-caddyfile.sh
> ```

## References
- [AdGuard Home Documentation](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [Caddy Documentation](https://caddyserver.com/docs/)