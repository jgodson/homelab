# Home Assistant

## Overview
Home Assistant is a home automation platform that puts local control and privacy first. It integrates with various smart home devices and services, providing a central hub for home automation.

## System Requirements

### Hardware Recommendations
- **CPU**: 4 Cores
- **RAM**: 4 GB
- **Disk**: 32 GB
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- Local DNS setup (recommended)
- InfluxDB for metrics (optional)

## Installation

### 1. Prepare the Environment

Create the required directories for Home Assistant:
```bash
mkdir -p homeassistant
```

### 2. Configuration

Copy the necessary files to your server:
```bash
scp -r ./docker-compose.yml configuration.yaml user@your-server-ip:~/homeassistant
```

Update the InfluxDB configuration in the configuration file:
- Open `configuration.yaml`
- Locate the InfluxDB integration section
- Update the host address if needed
- Replace `<REPLACE_ME>` with your InfluxDB organization ID and token

### 3. DNS Configuration

In order to send logs or metrics to local hostnames, we need to use the internal DNS server. Follow [these instructions](docs/dns-config-ubuntu.md) to configure DNS for Ubuntu if it has not already been set to use the DNS server.

### 4. Deployment

Start the Home Assistant services:
```bash
cd homeassistant && docker compose up -d
```

## Post-Installation Setup

1. Access the Home Assistant interface at https://ha.home.example.com or http://your-server-ip:8123
2. Complete the initial onboarding process
3. Add integrations for your smart home devices
4. Set up automations and scenes as needed

## Maintenance

### Backups
Home Assistant data is stored in the `./homeassistant` directory. Consider setting up regular backups of this directory.

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
- For integration issues, check the Home Assistant logs and verify device connectivity

## References
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Community Forum](https://community.home-assistant.io/)
- [Integrations List](https://www.home-assistant.io/integrations/)