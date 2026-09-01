#!/usr/bin/env bash

set -euo pipefail

secrets_file="${1:-/home/manager/docker/ha/secrets.yaml}"
devices_file="${GOVEE_DEVICES_FILE:-/home/manager/govee-devices.json}"

if [[ ! -r "$secrets_file" ]]; then
  echo "Cannot read $secrets_file" >&2
  exit 1
fi

# Authenticate before asking for the key so the secret is never mistaken for a
# sudo password.
sudo -v

read -rsp 'Govee API key (input hidden): ' govee_key
printf '\n'

if [[ ! "$govee_key" =~ ^[A-Za-z0-9._-]{16,}$ ]]; then
  echo "That does not look like a valid Govee API key." >&2
  exit 1
fi

temporary_secrets="$(mktemp)"
temporary_devices="$(mktemp)"
curl_config="$(mktemp)"
cleanup() {
  rm -f "$temporary_secrets" "$temporary_devices" "$curl_config"
  unset govee_key
}
trap cleanup EXIT
chmod 600 "$temporary_secrets" "$temporary_devices" "$curl_config"

printf 'header = "Content-Type: application/json"\n' >"$curl_config"
printf 'header = "Govee-API-Key: %s"\n' "$govee_key" >>"$curl_config"

curl --fail --silent --show-error \
  --config "$curl_config" \
  'https://openapi.api.govee.com/router/api/v1/user/devices' \
  >"$temporary_devices"

python3 - "$temporary_devices" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    response = json.load(handle)

if response.get("code") != 200:
    raise SystemExit(
        f"Govee rejected the request: {response.get('message', 'unknown error')}"
    )

devices = response.get("data") or []
h5179_devices = [device for device in devices if device.get("sku") == "H5179"]
print(f"Govee API key validated; account returned {len(devices)} device(s).")
print(f"Found {len(h5179_devices)} H5179 sensor(s).")
PY

h5179_payload="$(python3 - "$temporary_devices" <<'PY'
import json
import sys
import uuid

with open(sys.argv[1], encoding="utf-8") as handle:
    devices = json.load(handle).get("data") or []

h5179_devices = [device for device in devices if device.get("sku") == "H5179"]
if len(h5179_devices) != 1:
    raise SystemExit(
        "Expected exactly one H5179 sensor; select the intended device manually."
    )

device = h5179_devices[0]
print(json.dumps({
    "requestId": str(uuid.uuid4()),
    "payload": {"sku": device["sku"], "device": device["device"]},
}, separators=(",", ":")))
PY
)"

found_api_key=false
found_h5179_payload=false
while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    govee_api_key:*)
      if [[ "$found_api_key" == false ]]; then
        printf 'govee_api_key: "%s"\n' "$govee_key" >>"$temporary_secrets"
        found_api_key=true
      fi
      ;;
    govee_h5179_state_payload:*)
      if [[ "$found_h5179_payload" == false ]]; then
        printf "govee_h5179_state_payload: '%s'\n" "$h5179_payload" >>"$temporary_secrets"
        found_h5179_payload=true
      fi
      ;;
    *)
      printf '%s\n' "$line" >>"$temporary_secrets"
      ;;
  esac
done <"$secrets_file"

if [[ "$found_api_key" == false ]]; then
  printf 'govee_api_key: "%s"\n' "$govee_key" >>"$temporary_secrets"
fi
if [[ "$found_h5179_payload" == false ]]; then
  printf "govee_h5179_state_payload: '%s'\n" "$h5179_payload" >>"$temporary_secrets"
fi

# The deployment owner can maintain this file; the Home Assistant container
# runs as root and can still read it. Mode 0600 keeps it private from other users.
sudo install -o manager -g manager -m 0600 "$temporary_secrets" "$secrets_file"
install -m 0600 "$temporary_devices" "$devices_file"

echo "Saved or replaced the key securely and wrote the device inventory to $devices_file."
