### VM Config
- CPU: 1 Cores
- RAM: 2 GB
- Disk: 10 GB (Shared for HA)
- OS: Ubuntu server minimal
- Use static IP (For metrics scraping, otherwise does not matter)

### To get running

1. Install `cloudflared` and set up a tunnel connection in the Cloudflare Zero Trust Dashboard.
    ```bash
    sudo apt-get install cloudflared
    ```

1. Modify the systemd service to expose metrics for Prometheus to scrape:

    ```bash
    # Find the cloudflared service file
    sudo systemctl status cloudflared

    # Edit the service file (typically at /etc/systemd/system/cloudflared.service
    sudo nano /etc/systemd/system/cloudflared.service
    ```

1. In the service file, modify the Service section add environment variables. We can also remove `--no-autoupdate` from the command as we are replacing that.

    ```bash
    [Service]
    ...
    ExecStart=/usr/local/bin/cloudflared tunnel run --token <token>
    Environment="TUNNEL_METRICS=0.0.0.0:2000"
    Environment="NO_AUTOUPDATE=true"
    ```

1. Save the file and reload the systemd configuration

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart cloudflared
    ```

1. Verify that the metrics endpoint is working: `curl http://localhost:2000/metrics`

### Updating cloudflared

`sudo apt-get upgrade cloudflared`