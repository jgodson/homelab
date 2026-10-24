# Panel Heat Monitor

USB-powered ESP32 with two DS18B20 probes for monitoring electrical panel
temperature. Hostname: `panel-heat-monitor.local`.

## Operation

- Reads both probes every 5 seconds.
- Raises heat warnings above **60°C** and clears them below **58°C**.
- Sends Home Assistant and iPhone notifications for heat, probe faults, or a
  monitor that is offline for one minute.

The probes are aligned at room temperature; absolute accuracy at 60°C has not
been verified. This monitor provides no automatic shutoff. Keep hardware and
probe wiring clear of energized parts.

## Hardware

ESP32 DevKit V1; both probes share the one-wire bus on **GPIO4**.

| Probe | Offset |
| --- | --- |
| 1 | +0.125°C |
| 2 | 0°C |

## Setup and updates

Copy `secrets.example.yaml` to `secrets.yaml` and fill in the credentials and
probe addresses.
Keep secrets out of Git and preserve the device's existing API and OTA keys.

On the ESPHome host, place `panel-heat-monitor.yaml` and `secrets.yaml` in
`/config`, then build and upload over Wi-Fi:

```bash
docker exec \
  -e ESPHOME_ESP_IDF_PREFIX=/config/.esphome/idf \
  esphome esphome run /config/panel-heat-monitor.yaml \
  --device panel-heat-monitor.local
```
