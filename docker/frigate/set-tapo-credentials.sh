#!/usr/bin/env bash
set -euo pipefail

target="${1:-/home/manager/frigate.env}"
target_dir="$(dirname "$target")"
umask 077

read -r -p "Tapo Camera Account username: " tapo_user
read -r -s -p "Tapo Camera Account password: " tapo_password
printf '\n'
read -r -p "Local Tapo RTSP host and port: " tapo_local_host
read -r -p "RV Tailscale RTSP proxy host and port: " tapo_rv_host

if [[ -z "$tapo_local_host" || "$tapo_local_host" == *[[:space:]]* ]]; then
  printf 'Local Tapo host must be a non-empty host:port value without spaces.\n' >&2
  exit 1
fi

if [[ -z "$tapo_rv_host" || "$tapo_rv_host" == *[[:space:]]* ]]; then
  printf 'RV proxy host must be a non-empty host:port value without spaces.\n' >&2
  exit 1
fi

urlencode() {
  python3 -c 'import sys; from urllib.parse import quote; print(quote(sys.argv[1], safe=""))' "$1"
}

tapo_user_encoded="$(urlencode "$tapo_user")"
tapo_password_encoded="$(urlencode "$tapo_password")"
temporary_file="$(mktemp "$target_dir/.frigate.env.XXXXXX")"
trap 'rm -f "$temporary_file"' EXIT

if [[ -f "$target" ]]; then
  awk -F= '
    $1 != "FRIGATE_TAPO_LOCAL_USER" &&
    $1 != "FRIGATE_TAPO_LOCAL_PASSWORD" &&
    $1 != "FRIGATE_TAPO_LOCAL_HOST" &&
    $1 != "FRIGATE_TAPO_RV_HOST"
  ' "$target" > "$temporary_file"
fi

printf '%s\n' \
  "FRIGATE_TAPO_LOCAL_USER=$tapo_user_encoded" \
  "FRIGATE_TAPO_LOCAL_PASSWORD=$tapo_password_encoded" \
  "FRIGATE_TAPO_LOCAL_HOST=$tapo_local_host" \
  "FRIGATE_TAPO_RV_HOST=$tapo_rv_host" >> "$temporary_file"
chmod 600 "$temporary_file"
mv "$temporary_file" "$target"
trap - EXIT

unset tapo_user tapo_password tapo_user_encoded tapo_password_encoded
unset tapo_local_host tapo_rv_host
printf 'Saved Tapo credentials and private endpoints to %s\n' "$target"
