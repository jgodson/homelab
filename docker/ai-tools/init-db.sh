#!/bin/bash
set -e

# Read the secrets
POSTGRES_USER=$(cat /run/secrets/postgres_user)
POSTGRES_PASSWORD=$(cat /run/secrets/postgres_password)

# Create databases if they don't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-EOSQL
    SELECT 'CREATE DATABASE n8n' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'n8n')\gexec
    SELECT 'CREATE DATABASE flowise' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'flowise')\gexec
EOSQL

echo "Databases n8n and flowise created or already exist"
