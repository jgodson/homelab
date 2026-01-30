#!/bin/bash
set -e

# Configuration
REMOTE_USER="manager"
REMOTE_HOST="192.168.1.253"
REMOTE_DIR="~" # Adjust this to where your docker-compose.yaml lives on the server

# Colors
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Updating Caddyfile on ${REMOTE_HOST}...${NC}"

# Copy Caddyfile
scp Caddyfile ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/caddy/Caddyfile

# Reload Caddy
echo -e "${GREEN}Reloading Caddy...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} "sudo docker exec caddy caddy reload --config /etc/caddy/Caddyfile"

echo -e "${GREEN}Done!${NC}"
