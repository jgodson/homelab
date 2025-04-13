# AI Tools Suite

## Overview
This setup provides a comprehensive suite of AI tools for personal use, including Ollama for model hosting, Open WebUI for interaction, N8N for workflow automation and some supporting services.

## System Requirements

### Hardware Recommendations
- **CPU**: 28 Cores (I don't have GPU acceleration on my server 😭)
- **RAM**: 32 GB
- **Disk**: 128 GB
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose
- Local DNS setup (recommended)

## Installation

### 1. Prepare the Environment

Create the required directories for all services:
```bash
mkdir -p ollama open-webui postgres/data n8n/data n8n/shared n8n/backup qdrant/data secrets
```

### 2. Configure Secrets

Create the necessary secret files (I store these in 1Password):
```bash
echo -n "your_db_user" > secrets/postgres_user.txt
echo -n "your_secure_password" > secrets/postgres_password.txt
echo -n "n8n" > secrets/postgres_db.txt
echo -n "your_encryption_key" > secrets/n8n_encryption_key.txt
echo -n "your_jwt_secret" > secrets/n8n_jwt_secret.txt

# Secure the secret files
chmod 600 secrets/*
```

### 3. DNS Configuration

Configure system DNS for local domain resolution:
```bash
# Edit /etc/systemd/resolved.conf
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

Copy the Docker Compose file to your server:
```bash
scp -r ./docker-compose.yml user@your-server-ip:~/
```

Start all services:
```bash
docker compose up -d
```

## Post-Installation Setup

### Open WebUI
- **Access**: http://your-server-ip:3000
- Create an account and configure settings
- Add models through the admin interface

### N8N Workflow Automation
- **Access**: http://your-server-ip:5678
- Create workflows for automation tasks
- Pre-configured workflows will be automatically imported if placed in the `n8n/backup` directory

### Qdrant Vector Database
- **API Port**: 6333
- Metrics available at `/metrics` for Prometheus integration

### Ollama
- Accessible through Open WebUI at http://your-server-ip:3000/ollama/v1 (requires api token to be created in Open WebUI)

## Directory Structure

- `./ollama` - Stores Ollama models and configurations
- `./open-webui` - Stores Open WebUI data and settings
- `./postgres/data` - PostgreSQL database files
- `./n8n/data` - N8N configuration and runtime data
- `./n8n/backup` - Workflow and credential backups for automatic import
- `./n8n/shared` - Shared data directory accessible by N8N
- `./qdrant/data` - Qdrant vector database storage

## Maintenance

### Backups
Backing all of the above directories up is recommended (though you could skip ollama).

### Updates
To update the services:
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

- **Container issues**: Check logs with `docker compose logs -f <service_name>`
- **Database connection problems**: Verify PostgreSQL is healthy before using N8N: `docker compose ps postgres`
- **Secret files not being read**: Check file permissions are set to `600`
- **Service unavailable**: Ensure all required ports are accessible on your network

## References
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI Documentation](https://github.com/open-webui/open-webui)
- [N8N Documentation](https://docs.n8n.io/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)