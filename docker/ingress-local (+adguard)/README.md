 ### VM Config
- CPU: 2 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server

### To get running
Create the required directories to store data for ollama and openwebui.

`mkdir adguard adguard/work adguard/conf caddy caddy/data caddy/config`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml ./Caddy-Dockerfile ./caddy $USER@$IP_ADDR:~/`

Start the services.

`docker compose up -d`

### Next steps

- Setup Adguard at <ip>:3000
- After that Adguard is available at adguard.home.jasongodson.com or <ip>:8080
- Metrics from caddy are available at <ip>:2019/metrics