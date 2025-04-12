# Local development
cd ~/Documents/github/homelab/website
npm install
npm run dev

### Visit local server at http://localhost:3000

# Build versioned assets
npm run build

# Deploy to remote server
npm run deploy

# Deployment Prerequisites
- SSH access to your server must be configured
- Edit deploy.sh to set your server details:
    - SERVER: Your server's hostname or IP address
    - REMOTE_USER: Your SSH username
    - REMOTE_PATH: Target path on the remote server

# Setup ssh access
If you haven't already configured ssh access to this server:

1. Configure SSH key-based authentication for password-less deployment:

    `ssh-copy-id your-username@your-server-hostname`

2. Add server to your SSH config for easier access:

    `nano ~/.ssh/config`

```bash
Host myserver
    HostName your-server-hostname
    User your-username
    IdentityFile ~/.ssh/id_rsa
```

3. Test connection with `ssh myserver`