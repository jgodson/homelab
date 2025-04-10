### VM Config
- CPU: 28 Cores (No GPU)
- RAM: 32 GB
- Disk: 128 GB
- OS: Ubuntu server
- Use static IP
- Install docker with OS (snap)

### To get running

On the Docker host, create the required directories to store data for services.

`mkdir -p ollama open-webui postgres/data n8n/data n8n/shared n8n/backup qdrant/data secrets`

Create required secret files. (These are in 1Password under `AI Tools Secrets`)

```bash
echo -n "your_db_user" > secrets/postgres_user.txt
echo -n "your_secure_password" > secrets/postgres_password.txt
echo -n "n8n" > secrets/postgres_db.txt
echo -n "your_encryption_key" > secrets/n8n_encryption_key.txt
echo -n "your_jwt_secret" > secrets/n8n_jwt_secret.txt

# Secure the secret files
chmod 600 secrets
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

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml $USER@$IP_ADDR:~/`

Start the services.

`docker compose up -d`

### Next Steps

#### Open WebUI

- URL: http://$IP_ADDR:3000
- Setup: Create an account and add models in the admin settings

#### N8N Workflow Automation

- URL: http://$IP_ADDR:5678
- Note: Pre-configured workflows will be automatically imported if you place them in the `n8n/backup` directory
- Setup: Create an account and add models in the admin settings

#### Qdrant Vector Database

- API Port: 6333
- Note: Metrics are available at `/metrics` for Prometheus.

#### Directory Structure

`./ollama` - Stores Ollama models and configurations
`./open-webui` - Stores Open WebUI data and settings
`./postgres/data` - PostgreSQL database files
`./n8n/data` - N8N configuration and runtime data
`./n8n/backup` - Place your workflow and credential backups here for automatic import
`./n8n/backup/workflows` - N8N workflow files
`./n8n/backup/credentials` - N8N credential files
`./qdrant/data` - Qdrant vector database storage
`./n8n/shared` - Shared data directory accessible by N8N

### Tips
- Ensure all environment variables are set before starting the services
- For n8n automated imports, place each workflow and credential in separate files
- Ollama is embedded within Open WebUI and accessible on port `11434` externally.

### Troubleshooting

- Check container logs: `docker compose logs -f <service_name>`
- Ensure directories have proper permissions
- Verify PostgreSQL is healthy before using n8n: `docker compose ps postgres`
- If secrets are not being read properly, verify file permissions are set to `600`