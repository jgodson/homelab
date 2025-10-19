#!/bin/bash
#
# sync-configs.sh - Copy and redact Talos configs from local machine
#
# Usage: ./sync-configs.sh
#
# This script:
# 1. Retrieves the current Talos machine config from a control plane node
# 2. Redacts sensitive information (secrets, tokens, keys, certificates)
# 3. Saves the redacted version to this directory for version control
#

set -e

# Configuration
CONTROL_PLANE_NODE="192.168.1.31"
OUTPUT_FILE="controlplane-config.yaml"
TEMP_FILE="/tmp/talos-config-temp.yaml"

echo "🔧 Retrieving Talos machine config from ${CONTROL_PLANE_NODE}..."
# Use talosctl read to get the actual machine config file from the node
talosctl read /system/state/config.yaml -n "${CONTROL_PLANE_NODE}" > "${TEMP_FILE}"

echo "🔒 Redacting sensitive information..."

# Create redacted version
cat "${TEMP_FILE}" | \
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
  > "${OUTPUT_FILE}"

# Cleanup
rm -f "${TEMP_FILE}"

echo "✅ Config saved to ${OUTPUT_FILE} with sensitive data redacted"
echo ""
echo "Summary:"
echo "  - Certificates: REDACTED"
echo "  - Private keys: REDACTED"
echo "  - Tokens: REDACTED"
echo "  - Secrets: REDACTED"
echo ""
echo "The config should now be safe to commit to GitHub, however please review it carefully before doing so!"
