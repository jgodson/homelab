# Pool Temperature Sensor

ESPHome configuration for the battery-powered backyard pool temperature
sensor. The device reports pool water temperature, outdoor temperature, and
the two-cell CR123A battery voltage to Home Assistant.

## Hardware connections

- DS18B20 one-wire data: `GPIO4`
- Battery voltage divider output: `GPIO34`
- Both DS18B20 probes share the one-wire bus and adapter board.
- Pool probe address: `0xb0000000235efe28`
- Outdoor probe address: `0xae0000002292d128`

The battery ADC multiplier, `3.1396`, is calibrated for the installed voltage
divider and ESP32 ADC reading. Recheck it against a multimeter if resistor
values or boards change.

## Secrets

Copy `secrets.example.yaml` to `secrets.yaml` in this directory and replace the
placeholder values. The real file is ignored by Git. Do not put Wi-Fi
credentials, API encryption keys, or OTA passwords in the device YAML.

## Operation and updates

During normal operation the device stays awake for 45 seconds, publishes its
readings, and deep-sleeps for 10 minutes. To perform an OTA update, enable
**Pool Temperature Sensor OTA Mode** in Home Assistant and wait for the next
wake cycle. Disable it after the update to resume deep sleep.

When deploying through the homelab ESPHome container, copy the device YAML and
local secrets into its `/config` directory. If invoking the CLI directly in
the existing container, reuse the cached ESP-IDF toolchain:

```bash
docker exec \
  -e ESPHOME_ESP_IDF_PREFIX=/config/.esphome/idf \
  esphome esphome run /config/pool-temperature-sensor.yaml \
  --device pool-temperature-sensor.local
```
