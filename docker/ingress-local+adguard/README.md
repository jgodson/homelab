 ### VM Config
- CPU: 2 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server
- Use static IP

### To get running
Create the required directories to store data for caddy and adguard.

`mkdir -p adguard/work adguard/conf caddy/data caddy/config caddy/secrets`

Create the env file. This is in `Caddy .env` in 1Password. Create the `.env` file inside the `caddy` folder (ie: `caddy/.env`). Then paste the contents in there.

Afterwards, set the permissions on it
```bash
chmod 600 caddy/.env
```

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml ./Caddy-Dockerfile ./caddy $USER@$IP_ADDR:~/`

Start the services.

`docker compose up -d`

### Next steps

- Setup Adguard at <ip>:3000
- After that Adguard is available at adguard.home.jasongodson.com or <ip>:8080
- Metrics from Caddy are available at <ip>:2019/metrics