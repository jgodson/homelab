# Home Assistant

## Overview
Home Assistant is a home automation platform that puts local control and privacy first. It integrates with various smart home devices and services, providing a central hub for home automation.

## System Requirements

### Hardware Recommendations
- **CPU**: 4 Cores
- **RAM**: 4 GB
- **Disk**: 32 GB
    - Use `Cache: Writeback` for best performance on HDD
    - Additionally after creating run `zfs set sync=disabled rpool/data/vm-<vmid>-disk-0`
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- Local DNS setup (recommended)
- InfluxDB for metrics (optional)

## Installation

### 1. Prepare the Environment

Create the required directories for Home Assistant and ESPHome:
```bash
mkdir -p docker/ha docker/esphome
cp esphome-dashboard.env.example esphome-dashboard.env
```

Edit `esphome-dashboard.env` and replace the example ESPHome dashboard
credentials before starting the services. The credentials file and `esphome`
configuration directory are intentionally excluded from Git because they
contain credentials and device API keys.

### 2. Configuration

Copy the necessary files to your server:
```bash
scp -r ./docker-compose.yml configuration.yaml user@your-server-ip:~/homeassistant
```

Configure the InfluxDB connection in Home Assistant under **Settings > Devices & services**.
Connection and authentication settings are managed in the UI; `configuration.yaml`
contains only the additional YAML options that Home Assistant still supports.

Configure HTTP and reverse proxy settings under **Settings > System > Network**.
The HTTP integration is UI-managed and must not be added to `configuration.yaml`.

### 3. DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal DNS server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server.

### 4. Deployment

Start the Home Assistant and ESPHome services:
```bash
cd homeassistant && docker compose up -d
```

## Post-Installation Setup

1. Access the Home Assistant interface at https://ha.home.example.com or http://your-server-ip:8123
2. Access ESPHome Device Builder at https://esphome.home.jasongodson.com and
   sign in with the credentials from `esphome-dashboard.env`. Direct access
   remains available at http://your-server-ip:6052 for troubleshooting.
3. Complete the initial Home Assistant onboarding process
4. Add integrations for your smart home devices
5. Set up automations and scenes as needed

The first ESPHome firmware installation still requires a USB connection. If
the ESP board is connected to another computer, compile/download the firmware
from Device Builder and flash it using ESPHome Web on that computer. Later
firmware updates can be installed over Wi-Fi.

## Maintenance

### Backups
Home Assistant data is stored in `./docker/ha`, and ESPHome device
configurations are stored in `./docker/esphome`. Include both directories in regular
backups.

### Updates
To update Home Assistant:
```bash
cd homeassistant
docker compose pull
docker compose up -d
```

## Integrations

Home Assistant can integrate with numerous smart home platforms and services, some of the ones I use are (most things are auto-discovered):
- Google Home
- Media players
- Weather services
- TP-Link Kasa power strip
- Ecobee Theromstat
- HP Printer

## Troubleshooting

- If Home Assistant becomes unresponsive:
  - Check container logs: `docker logs homeassistant`
  - Restart the container: `docker compose restart homeassistant`
- If ESPHome Device Builder is unavailable:
  - Check container logs: `docker logs esphome`
  - Restart the container: `docker compose restart esphome`
- When running an ESPHome build or OTA update with `docker exec`, explicitly
  reuse Device Builder's ESP-IDF toolchain:
  ```bash
  docker exec \
    -e ESPHOME_ESP_IDF_PREFIX=/config/.esphome/idf \
    esphome esphome run /config/device.yaml --device device.local
  ```
  Without that environment variable, the CLI may download a second toolchain
  under `/root/.cache/esphome/idf` and conflict with cached build metadata.
- For integration issues, check the Home Assistant logs and verify device connectivity

## References
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Community Forum](https://community.home-assistant.io/)
- [Integrations List](https://www.home-assistant.io/integrations/)
- [ESPHome Docker guide](https://esphome.io/guides/getting_started_command_line/)
