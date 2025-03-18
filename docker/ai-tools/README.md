### VM Config
- CPU: 28 Cores (No GPU)
- RAM: 32 GB
- Disk: 128 GB
- OS: Ubuntu server

### To get running

Create the required directories to store data for ollama and openwebui.

`mkdir ollama open-webui`

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml $USER@$IP_ADDR:~/`

Start the services.

`docker compose up -d`

### Next steps
- Create an account at <ip>:3000
- Add models in the admin settings