#!/bin/bash

# Ensure we have a build first
npm run build

# Remote server details
SERVER="192.168.1.20" # Replace with your server hostname/IP
DOMAIN="jasongodson.com" # Replace with your domain
REMOTE_USER="manager"   # Replace with your SSH username
REMOTE_PATH="~/caddy/site" # Replace with the path on your server

# Sync the dist directory to the remote server (checksum avoids timestamp-only churn)
echo "🚢 Deploying to $SERVER..."
rsync -rlv --checksum --delete-delay --exclude ".DS_Store" dist/ $REMOTE_USER@$SERVER:$REMOTE_PATH

echo "🚀 Deployment complete!"
echo "🔍 View site at https://$DOMAIN"
