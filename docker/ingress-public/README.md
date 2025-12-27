# Public Ingress with Cloudflare Tunnel

## Overview
This setup provides secure public access to homelab services through Cloudflare Tunnels, eliminating the need to open ports on your router. It combines Caddy as a reverse proxy with Cloudflared for secure tunneling and CrowdSec for advanced security protection.

## System Requirements

### Hardware Recommendations
- **CPU**: 4 Cores
- **RAM**: 4 GB
- **Disk**: 32 GB (Shared for high availability)
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- Cloudflare account with a registered domain
- SSH access to the server

## Installation

### 1. Network Optimization

For better HTTP/3 performance with Caddy, increase the UDP buffer sizes:

```bash
# Add these lines to /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
# Increase UDP buffer size for QUIC/HTTP3
net.core.rmem_max=8388608
net.core.wmem_max=8388608
net.core.rmem_default=1048576
net.core.wmem_default=1048576
EOF

# Apply the settings
sudo sysctl -p
```

### 2. Security Hardening

#### Disable IPv6 (Recommended)
Since Cloudflared and Caddy don't require IPv6, disable it to reduce attack surface:

1. Edit Docker daemon settings:
```bash
sudo nano /var/snap/docker/current/config/daemon.json
```

Add or merge with existing content:
```json
{
  "ipv6": false,
  "ip6tables": false
}
```

2. Restart Docker:
```bash
sudo snap restart docker
```

3. Disable IPv6 at host level:
```bash
sudo nano /etc/sysctl.conf
```

Add these lines:
```
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

4. Apply sysctl changes:
```bash
sudo sysctl -p
```

### 3. Prepare Environment

#### Set up logging
Use the [promtail script](../../observability-config/README.md#use-the-setup-script) to configure centralized logging.

#### Create directories
```bash
mkdir -p cloudflared caddy/site caddy/data caddy/config caddy/logs crowdsec/config crowdsec/data
```

#### DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal DNS server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server.

#### Configure environment files
1. Create an env file for Cloudflared (I store these in 1Password):
```bash
# Create .env file in cloudflared directory
# Format is TUNNEL_TOKEN=xxxx
nano cloudflared/.env
```

2. Generate a bcrypt password hash for basic authentication:
```bash
# If Caddy is already running
docker exec -it caddy caddy hash-password -a bcrypt

# Or run a temporary Caddy container
docker run --rm -it caddy:latest caddy hash-password -a bcrypt
```

> [!NOTE]
> The command will prompt you to enter and confirm your password (this is what you will send when authenticating with the server). After processing, it will output a bcrypt hash like:
> `$2a$14$wVsaPvJnzUY.R1w6FTXI5O.QW8c5XGQv.SJMwjAFLSJ/KMveaBQYu`

3. Create an env file for Caddy with required variables:
```bash
nano caddy/.env
```

Add the following content (replacing the values with your actual data):
```bash
CROWDSEC_API_KEY=changeme
TELEMETRY_USERNAME=yourtelemetryuser
TELEMETRY_PASSWORD_HASH='$2a$14$ExampleHashWithSpecialChars'
```

> [!IMPORTANT]
> - When using bcrypt hashes in environment files, enclose them in single quotes to prevent special character issues
> - Make sure there are NO spaces around the equals sign
> - Avoid using special characters in the username
> - Do not add any comments on the same line as the variables

### 4. Deploy Application Files

Copy the necessary files to your server:
```bash
scp -r ./caddy ./cloudflared ./crowdsec ./docker-compose.yaml Caddy-Dockerfile user@your-server-ip:~/
```

Set proper permissions on the configuration files:
```bash
# Secrets files
sudo chown root:root cloudflared/.env
sudo chmod 600 cloudflared/.env
sudo chown root:root caddy/.env
sudo chmod 600 caddy/.env

# Config files
sudo chmod 644 cloudflared/config.yaml
sudo chmod 644 caddy/Caddyfile
```

### 5. Start Services

Launch the containers:
```bash
docker compose up -d
```

> [!TIP]
> If you see errors like `The "XXX" variable is not set. Defaulting to a blank string`, check your .env file and ensure you used single quotes around variables with special characters.

## Post-Installation Setup

### Configure CrowdSec

1. Generate a bouncer API key:
```bash
docker exec crowdsec cscli bouncers add caddy-bouncer
```

2. Update the environment file with the generated API key:
```bash
# Update CROWDSEC_API_KEY with the generated key
sudo nano caddy/.env
```

3. Restart the stack to apply changes:
```bash
docker compose up -d --force-recreate
```

### Cloudflare DNS Configuration

After setting up the tunnel, configure DNS records in Cloudflare:

1. Get your tunnel ID (via Cloudflare Dashboard or command line):
   
   **From Cloudflare Dashboard:**
   - Go to cloudflare.com → Zero Trust → Network → Tunnels
   - Find your tunnel and copy its ID

2. In the Cloudflare dashboard:
   - Navigate to your domain
   - Go to the DNS tab
   - Remove any existing A or AAAA records for domains you want to route through the tunnel
   - Add these CNAME records:

| Type  | Name | Target                         | Proxy status |
|-------|------|--------------------------------|--------------|
| CNAME | @    | {TUNNEL_ID}.cfargotunnel.com   | Proxied ☁️   |
| CNAME | *    | {TUNNEL_ID}.cfargotunnel.com   | Proxied ☁️   |

3. Verify the tunnel is working:
```bash
curl -I https://example.com
```

## Maintenance

### Website Deployment

To deploy the website to the Caddy server:
- Follow the instructions in the [website README](/website/README.md#deploy-to-remote-server)

### Security Monitoring

Monitor CrowdSec for security events:
```bash
# View blocked IPs
docker exec -it crowdsec cscli decisions list

# View detected security events
docker exec -it crowdsec cscli alerts list
```

### Updates

To update the services:
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

- **Tunnel Connection Issues**: Check cloudflared logs with `docker compose logs -f cloudflared`
- **Reverse Proxy Issues**: Check Caddy logs with `docker compose logs -f caddy`
- **Security Events**: Examine CrowdSec logs with `docker compose logs -f crowdsec`

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
- [Cloudflare Tunnels Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [CrowdSec Documentation](https://docs.crowdsec.net/)