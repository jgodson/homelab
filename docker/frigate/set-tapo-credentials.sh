#!/usr/bin/env bash
set -euo pipefail

target="${1:-/home/manager/frigate.env}"
target_dir="$(dirname "$target")"
umask 077

read -r -p "Tapo Camera Account username: " tapo_user
read -r -s -p "Tapo Camera Account password: " tapo_password
printf '\n'

urlencode() {
  python3 -c 'import sys; from urllib.parse import quote; print(quote(sys.argv[1], safe=""))' "$1"
}

tapo_user_encoded="$(urlencode "$tapo_user")"
tapo_password_encoded="$(urlencode "$tapo_password")"
temporary_file="$(mktemp "$target_dir/.frigate.env.XXXXXX")"
trap 'rm -f "$temporary_file"' EXIT

printf 'FRIGATE_TAPO_LOCAL_USER=%s\nFRIGATE_TAPO_LOCAL_PASSWORD=%s\n' \
  "$tapo_user_encoded" "$tapo_password_encoded" > "$temporary_file"
chmod 600 "$temporary_file"
mv "$temporary_file" "$target"
trap - EXIT

unset tapo_user tapo_password tapo_user_encoded tapo_password_encoded
printf 'Saved URL-encoded Tapo credentials to %s\n' "$target"
