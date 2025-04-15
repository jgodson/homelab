# Frigate NVR
⚠️ This one is a WIP (well, more so than everything else 😄), I haven't spent much time getting this one set up yet ⚠️

## Overview
Frigate is a Network Video Recorder (NVR) that uses computer vision to provide object detection for IP cameras. It integrates with Home Assistant and uses hardware acceleration to efficiently process multiple camera streams.

## System Requirements

### Hardware Recommendations
- **CPU**: 12 Cores (for CPU-based object detection)
- **RAM**: 8 GB
- **Disk**: 256 GB (Can be adjusted according to your needs)
- **Network**: Static IP address

### Prerequisites
- Ubuntu Server (or similar Linux distribution)
- Docker and Docker Compose (Can be installed with Ubuntu via snap)
- Compatible IP cameras

## Installation

### 1. Prepare the Environment

Create the required directories for Frigate:
```bash
mkdir -p storage config
```

### 2. Configuration

Copy the Docker Compose and config file to your server:
```bash
scp -r ./docker-compose.yml config.yml user@your-server-ip:~/
```

Modify the configuration file to:
- Set camera details in `config.yml`
- Update InfluxDB configuration with the correct host, org ID, and token

### 3. Deployment

Start the services:
```bash
docker compose up -d
```

## Post-Installation Setup

1. Access the Frigate web interface at http://your-server-ip:5000
2. Create an account in the Settings section
3. Configure detection zones and object filters as needed
4. Set up recording retention policies

## Maintenance

### Recordings Management
Frigate automatically manages recordings based on your retention settings.

### Updates
To update Frigate:
```bash
docker compose pull
docker compose up -d
```

## Integration with Home Assistant

Frigate can be integrated with Home Assistant using:
- The Frigate integration in HACS
- MQTT for event notifications
- Direct camera feed integration

## Troubleshooting

- If detections aren't working, check:
  - CPU/GPU utilization
  - Camera stream format (H.264 is recommended)
  - Container logs: `docker logs frigate`
- For performance issues, review the hardware acceleration settings

## References
- [Frigate Documentation](https://docs.frigate.video/)
- [Reference Config](https://docs.frigate.video/configuration/reference)
- [Hardware Acceleration Guide](https://docs.frigate.video/configuration/hardware_acceleration)
- [Camera Compatibility](https://docs.frigate.video/configuration/camera_specific)