### VM Config
- CPU: 4 Cores
- RAM: 4 GB
- Disk: 32 GB (Shared for HA)
- OS: Ubuntu server
- Use static IP

### To get running

Create the required directories to store data for homeassistant.

`mkdir homeassistant`

Change the influxdb config in the [configuration file](./configuration.yaml) to point to the correct host (if it's changed), then add the org id and the token where it says `<REPLACE_ME>` in the docker compose file.

This assumes you have ssh access. Otherwise you can also copy & paste the docker compose file in a text editor, etc.

`scp -r ./docker-compose.yml configuration.yaml $USER@$IP_ADDR:~/homeassistant`

**DNS Configuration**
- Configure system DNS to use 192.168.1.253 in `/etc/systemd/resolved.conf`:
    ```
    [Resolve]
    DNS=192.168.1.253
    Domains=~home.jasongodson.com
    FallbackDNS=1.1.1.1
    ```
- Restart systemd-resolved: `sudo systemctl restart systemd-resolved`

Start the services.

`docker compose up -d`

You should now be able to login at https://ha.home.jasongodson.com