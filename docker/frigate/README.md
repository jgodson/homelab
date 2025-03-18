### VM Config
- CPU: 12 Cores (for CPU detectors)
- RAM: 8 GB
- Disk: 256 GB
- OS: Ubuntu server

### To get running

Create the required directories to store data for ollama and openwebui.

`mkdir storage config`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml $USER@$IP_ADDR:~/`

Change the influxdb config to point to the correct host, add the org id, and the token where it says `<REPLACE_ME>` in the docker compose file.

Start the services.

`docker compose up -d`

### Next steps
- Go to <ip>:8971 and create an account
- Other setup as required in `Settings`