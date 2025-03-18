### VM Config
- CPU: 4 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server

### To get running

Create the required directories to store data for ollama and openwebui.

`mkdir home-assistant`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml $USER@$IP_ADDR:~/`

Change the influxdb config to point to the correct host, add the org id, and the token where it says `<REPLACE_ME>` in the docker compose file.

Start the services.

`docker compose up -d`