### VM Config
- CPU: 2 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server

### To get running
Create the required directories to store data for Traefik.

`mkdir -p traefik`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml $USER@$IP_ADDR:~/`

Start the services.

`docker compose up -d`