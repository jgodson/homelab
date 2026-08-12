# Home Assistant and ESPHome Notes

These instructions apply to the Home Assistant and ESPHome Docker deployment in
this directory.

## ESPHome CLI builds

- ESPHome Device Builder stores its ESP-IDF toolchain under
  `/config/.esphome/idf` inside the `esphome` container.
- Commands started with `docker exec` do not inherit environment variables that
  Device Builder sets after the container starts. Always pass
  `ESPHOME_ESP_IDF_PREFIX=/config/.esphome/idf` to ESPHome CLI build/run
  commands so they reuse the dashboard toolchain instead of downloading another
  copy under `/root/.cache/esphome/idf`.
- Example:

  ```bash
  docker exec \
    -e ESPHOME_ESP_IDF_PREFIX=/config/.esphome/idf \
    esphome esphome run /config/device.yaml --device device.local
  ```

- If an older build was created using a different ESP-IDF Python path and ESPHome
  reports that the active Python environment differs from the configured one,
  run `esphome clean` for that device configuration and rebuild. This deletes
  generated build artifacts only; do not delete the device YAML or secrets.

