# AI Tools Suite

## Overview
This setup provides a comprehensive suite of AI tools for personal use, including Ollama for model hosting, Open WebUI for interaction, N8N for workflow automation, Flowise for visual AI workflow building, and some supporting services.

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
mkdir -p ollama open-webui postgres/data n8n/data n8n/shared n8n/backup qdrant/data flowise secrets
```

### 2. Configure Secrets

Create the necessary secret files (I store these in 1Password):
```bash
echo -n "your_db_user" > secrets/postgres_user.txt
echo -n "your_secure_password" > secrets/postgres_password.txt
echo -n "n8n" > secrets/postgres_db.txt
echo -n "flowise" > secrets/flowise_db.txt
echo -n "your_encryption_key" > secrets/n8n_encryption_key.txt
echo -n "your_jwt_secret" > secrets/n8n_jwt_secret.txt

# Secure the secret files
chmod 600 secrets/*
```

> **Note**: If you've already set permissions on the secrets directory, you can use `sudo tee secrets/flowise_db.txt <<< "flowise"` instead of the echo command.

### 3. DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal DNS server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server.

### 4. Deployment

Copy the Docker Compose and init-db files to your server:
```bash
scp -r ./docker-compose.yml user@your-server-ip:~/
scp -r ./init-db.sh user@your-server-ip:~/postgres/
```

Start all services (databases will be created automatically):
```bash
docker compose up -d
```

> **Note**: The `init-db.sh` script will automatically create the `n8n` and `flowise` databases on first startup.

## Post-Installation Setup

### Open WebUI
- **Access**: http://your-server-ip:3000
- Create an account and configure settings
- Add models through the admin interface

### Flowise
- **Access**: http://your-server-ip:3001
- Create an account on first visit
- Build visual AI workflows using the drag-and-drop interface
- Connect to your Ollama models through Open WebUI or directly

#### Connecting to Ollama
To connect Flowise to your Ollama models:
1. In Flowise, when adding a Chat Model node, select "ChatOllama"
2. Set the Base URL to: `http://open-webui:11434` (internal Docker network)
3. Specify your model name (e.g., `llama2`, `codellama`, etc.)
4. You can also connect directly to Ollama at `http://open-webui:11434/api` for API access

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
- `./flowise` - Flowise data including flows, credentials, and storage
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
- **Database connection problems**: Verify PostgreSQL is healthy before using N8N/Flowise: `docker compose ps postgres`
- **Secret files not being read**: Check file permissions are set to `600`
- **Service unavailable**: Ensure all required ports are accessible on your network
- **Flowise database issues**: Make sure the `flowise` database exists in PostgreSQL
- **Flowise can't connect to Ollama**: Verify Open WebUI is running and accessible at port 3000

## Service Ports

- **Open WebUI**: 3000
- **Flowise**: 3001  
- **N8N**: 5678
- **Qdrant**: 6333
- **PostgreSQL**: 5432 (internal only)

> **Note**: Flowise runs on port 3001 to avoid conflicts with Open WebUI which uses port 3000.

## References
- [Ollama Documentation](https://github.com/ollama/ollama)
- [Open WebUI Documentation](https://github.com/open-webui/open-webui)
- [N8N Documentation](https://docs.n8n.io/)
- [Flowise Documentation](https://docs.flowiseai.com/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)