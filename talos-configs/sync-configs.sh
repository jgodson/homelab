#!/bin/bash
#
# sync-configs.sh - Copy and redact Talos configs from local machine
#
# Usage: ./sync-configs.sh [--controlplane] [--worker]
#
# This script:
# 1. Retrieves the current Talos machine config from cluster nodes
# 2. Redacts sensitive information (secrets, tokens, keys, certificates)
# 3. Saves the redacted version to this directory for version control
#
# Options (default: sync all):
#   --controlplane  Sync controlplane config only
#   --worker        Sync worker config only
#   (no flags)      Sync both controlplane and worker configs
#

set -e

# Configuration
CONTROL_PLANE_NODE="192.168.1.31"
WORKER_NODE="192.168.1.33"
CONTROLPLANE_OUTPUT="controlplane-config.yaml"
WORKER_OUTPUT="worker-config.yaml"
TEMP_FILE="/tmp/talos-config-temp.yaml"

# Redaction function - strips all sensitive data from a Talos machine config
redact_config() {
  local input_file="$1"
  local output_file="$2"

  cat "${input_file}" | \
    # Redact base64-encoded certificates and keys (long base64 strings)
    sed -E 's/: (LS0tLS[A-Za-z0-9+/=]{50,})/: REDACTED_BASE64/g' | \
    # Redact full certificate blocks (PEM format) - delete lines between markers
    sed '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/d' | \
    sed '/-----BEGIN EC PRIVATE KEY-----/,/-----END EC PRIVATE KEY-----/d' | \
    sed '/-----BEGIN RSA PRIVATE KEY-----/,/-----END RSA PRIVATE KEY-----/d' | \
    sed '/-----BEGIN ED25519 PRIVATE KEY-----/,/-----END ED25519 PRIVATE KEY-----/d' | \
    sed '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/d' | \
    # Redact cluster secrets
    sed -E 's/(secret: )[A-Za-z0-9+/=]{20,}/\1REDACTED_SECRET/g' | \
    sed -E 's/(secretboxEncryptionSecret: )[A-Za-z0-9+/=]{20,}/\1REDACTED_SECRET/g' | \
    sed -E 's/(aescbcEncryptionSecret: )[A-Za-z0-9+/=]{20,}/\1REDACTED_SECRET/g' | \
    # Redact cluster tokens
    sed -E 's/(token: )[a-z0-9]{6}\.[a-z0-9]{16}/\1REDACTED_TOKEN/g' | \
    # Redact cluster ID
    sed -E 's/(id: )[A-Za-z0-9+/=_-]{20,}/\1REDACTED_ID/g' \
    > "${output_file}"
}

sync_node() {
  local node_ip="$1"
  local output_file="$2"
  local node_type="$3"

  echo "Retrieving Talos machine config from ${node_ip} (${node_type})..."
  talosctl read /system/state/config.yaml -n "${node_ip}" > "${TEMP_FILE}"

  echo "Redacting sensitive information..."
  redact_config "${TEMP_FILE}" "${output_file}"

  rm -f "${TEMP_FILE}"
  echo "Config saved to ${output_file} with sensitive data redacted"
  echo ""
}

# Parse arguments
SYNC_CONTROLPLANE=false
SYNC_WORKER=false

if [ $# -eq 0 ]; then
  # Default: sync all
  SYNC_CONTROLPLANE=true
  SYNC_WORKER=true
fi

for arg in "$@"; do
  case $arg in
    --controlplane)
      SYNC_CONTROLPLANE=true
      ;;
    --worker)
      SYNC_WORKER=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: ./sync-configs.sh [--controlplane] [--worker]"
      exit 1
      ;;
  esac
done

if [ "$SYNC_CONTROLPLANE" = true ]; then
  sync_node "${CONTROL_PLANE_NODE}" "${CONTROLPLANE_OUTPUT}" "controlplane"
fi

if [ "$SYNC_WORKER" = true ]; then
  sync_node "${WORKER_NODE}" "${WORKER_OUTPUT}" "worker"
fi

echo "Summary:"
echo "  - Certificates: REDACTED"
echo "  - Private keys: REDACTED"
echo "  - Tokens: REDACTED"
echo "  - Secrets: REDACTED"
echo ""
echo "The config(s) should now be safe to commit to GitHub, however please review carefully before doing so!"
