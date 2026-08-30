#!/usr/bin/env bash
set -euo pipefail

camera_ip="${1:-${RV_CAMERA_IP:-}}"
camera_rtsp_port="${2:-554}"
tailnet_rtsp_port="${3:-8554}"
operator_user="${SUDO_USER:-manager}"

if [[ "$EUID" -ne 0 ]]; then
  printf 'Run this script with sudo.\n' >&2
  exit 1
fi

if [[ -z "$camera_ip" ]]; then
  printf 'Usage: sudo %s CAMERA_IP [CAMERA_RTSP_PORT] [TAILNET_RTSP_PORT]\n' "$0" >&2
  printf 'Alternatively set RV_CAMERA_IP in the private environment.\n' >&2
  exit 1
fi

if [[ ! "$camera_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid camera IPv4 address: %s\n' "$camera_ip" >&2
  exit 1
fi

install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/trixie.noarmor.gpg \
  -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/raspbian/trixie.tailscale-keyring.list \
  -o /etc/apt/sources.list.d/tailscale.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
systemctl enable --now tailscaled

tailscale set --operator="$operator_user"

if ! tailscale ip -4 >/dev/null 2>&1; then
  runuser -u "$operator_user" -- tailscale up --hostname=rv-pi
fi

runuser -u "$operator_user" -- tailscale serve \
  --bg --yes --tcp="$tailnet_rtsp_port" \
  "tcp://${camera_ip}:${camera_rtsp_port}"

tailscale status
tailscale serve status
