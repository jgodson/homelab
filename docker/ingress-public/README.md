### VM Config
- CPU: 4 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server
- Use static IP
- Install docker with OS (snap)

### Setup
### Optimizing Network Performance

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
```

Then apply the settings
`sudo sysctl -p`

### Security Hardening

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

### To get running
This assumes you have ssh access.

Setup logging. Use the [promtail script](../../observability-config/README.md#use-the-setup-script)

Create the required directories to store data for Caddy and cloudflared.

`mkdir -p cloudflared caddy/site caddy/data caddy/config caddy/logs crowdsec/config crowdsec/data`

Create an env file for cloudflared. This is in `Cloudflared .env` in 1Password. Create the `.env` file inside the `cloudflared` folder (ie: `cloudflared/.env`). Then paste the contents in there.

Create an env file for caddy. This is temporary until you can generate an api key. Create the `.env` file inside the `crowdsec` folder (ie: `crowdsec/.env`). Then add `CROWDSEC_API_KEY=changeme`.

`scp -r ./caddy ./cloudflared ./crowdsec ./docker-compose.yaml Caddy-Dockerfile $USER@$IP_ADDR:~/`

Afterwards, set the proper permissions on the files:
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

Start the services.

`docker compose up -d`

### Security Setup with CrowdSec

This setup includes CrowdSec for advanced security protection:

1. Generate a bouncer API key:
```bash
docker exec crowdsec cscli bouncers add caddy-bouncer
```

2. Replace 'changeme' with the generated key in caddy/.env
```bash
sudo nano caddy/.env
```

3. Restart the stack:
```bash
docker compose up -d --force-recreate
```

4. View security metrics:
```bash
# See blocked IPs
docker exec -it crowdsec cscli decisions list

# See detected scenarios
docker exec -it crowdsec cscli alerts list
```

### Reload caddyfile without restart
If you make changes to the Caddyfile you can load the new configuration without restarting the container by running `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

### Cloudflare DNS Configuration
After setting up everything, you need to configure DNS records in Cloudflare:

1. Get your tunnel ID (use one of these methods):

   **Recommended: From Cloudflare Dashboard**
   - Go to cloudflare.com → Log in → Go to Zero Trust → Network → Tunnels
   - Find your tunnel (can use the connector ID from `docker logs cloudflared` to identify it, if needed) and copy its ID (make sure this is the Tunnel ID not the Connector ID)

   **Alternative: Using command line**
   ```bash
   # If you've properly set up the origin certificate:
   docker exec cloudflared cloudflared tunnel list
   
   # Or check directly in the credentials file:
   cat cloudflared/credentials.json | grep -o '"TunnelID":"[^"]*' | cut -d'"' -f4
   ```

2. In the Cloudflare dashboard navigate to the domain
3. Go to the DNS tab
4. **Important**: Remove any existing A or AAAA records for the root domain (@) and subdomains you want to route through the tunnel
5. Add these CNAME records:

| Type  | Name | Target                         | Proxy status |
|-------|------|--------------------------------|--------------|
| CNAME | @    | {TUNNEL_ID}.cfargotunnel.com   | Proxied ☁️   |
| CNAME | *    | {TUNNEL_ID}.cfargotunnel.com   | Proxied ☁️   |

Replace `{TUNNEL_ID}` with your actual tunnel ID from step 1.

6. Verify the tunnel is working:
```bash
curl -I https://jasongodson.com
```

The "*" wildcard record routes all subdomains to your tunnel, where they will be processed according to your ingress rules in the config.yaml file.