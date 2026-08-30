#!/usr/bin/env bash
set -euo pipefail

jellyfin_target="${1:-${JELLYFIN_TARGET:-}}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
environment_file="/etc/rv-jellyfin-proxy.env"

if [[ "$EUID" -ne 0 ]]; then
  printf 'Run this script with sudo.\n' >&2
  exit 1
fi

if [[ -z "$jellyfin_target" ]]; then
  printf 'Usage: sudo %s JELLYFIN_TAILSCALE_HOST:PORT\n' "$0" >&2
  printf 'Alternatively set JELLYFIN_TARGET in the private environment.\n' >&2
  exit 1
fi

if [[ ! "$jellyfin_target" =~ ^[A-Za-z0-9._-]+:([0-9]{1,5})$ ]]; then
  printf 'Invalid Jellyfin target: %s\n' "$jellyfin_target" >&2
  exit 1
fi

target_port="${BASH_REMATCH[1]}"
if (( target_port < 1 || target_port > 65535 )); then
  printf 'Invalid Jellyfin target port: %s\n' "$target_port" >&2
  exit 1
fi

temporary_environment="$(mktemp)"
trap 'rm -f -- "$temporary_environment"' EXIT
printf 'JELLYFIN_TARGET=%s\n' "$jellyfin_target" >"$temporary_environment"

install -o root -g root -m 0600 "$temporary_environment" "$environment_file"
install -o root -g root -m 0644 \
  "$script_dir/rv-jellyfin-proxy.socket" \
  "$script_dir/rv-jellyfin-proxy.service" \
  /etc/systemd/system/

systemctl daemon-reload
systemctl stop rv-jellyfin-proxy.service rv-jellyfin-proxy.socket
systemctl enable --now rv-jellyfin-proxy.socket
systemctl status rv-jellyfin-proxy.socket --no-pager
