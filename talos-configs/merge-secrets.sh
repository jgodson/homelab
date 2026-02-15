#!/bin/bash
#
# merge-secrets.sh - Merge secrets from a real config into the redacted template
#
# Usage: ./merge-secrets.sh <path-to-real-config> <output-file> [--worker]
# Example: ./merge-secrets.sh /path/to/backup-config.yaml new-controlplane.yaml
# Example: ./merge-secrets.sh /path/to/backup-worker.yaml new-worker.yaml --worker
#
# This takes secrets from a real config and merges them into the current
# redacted template (controlplane-config.yaml or worker-config.yaml).
#

set -e

# Parse arguments
USE_WORKER=false
REAL_CONFIG=""
OUTPUT_FILE=""

for arg in "$@"; do
  case $arg in
    --worker)
      USE_WORKER=true
      shift
      ;;
    *)
      if [ -z "$REAL_CONFIG" ]; then
        REAL_CONFIG="$arg"
      elif [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$arg"
      fi
      ;;
  esac
done

# Check arguments
if [ -z "$REAL_CONFIG" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <path-to-real-config> <output-file> [--worker]"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/backup-config.yaml new-controlplane.yaml"
    echo "  $0 /path/to/backup-worker.yaml new-worker.yaml --worker"
    echo ""
    echo "This merges secrets from a real config into the redacted template."
    exit 1
fi

# Select template based on node type
if [ "$USE_WORKER" = true ]; then
    TEMPLATE="worker-config.yaml"
else
    TEMPLATE="controlplane-config.yaml"
fi

# Validate inputs
if [ ! -f "$REAL_CONFIG" ]; then
    echo "Error: Real config file not found: $REAL_CONFIG"
    exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: Template file not found: $TEMPLATE"
    exit 1
fi

if [ -f "$OUTPUT_FILE" ]; then
    echo "Warning: Output file already exists: $OUTPUT_FILE"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo "🔧 Merging secrets from real config into template..."
echo ""
echo "  Template: $TEMPLATE"
echo "  Real config: $REAL_CONFIG"
echo "  Output: $OUTPUT_FILE"
echo ""

# Extract secrets from real config using yq (if available) or python
if command -v yq &> /dev/null; then
    echo "Using yq for YAML processing..."
    
    # Start with the template
    cp "$TEMPLATE" "$OUTPUT_FILE"
    
    # Extract and merge secrets
    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$TEMPLATE" "$REAL_CONFIG" > "$OUTPUT_FILE.tmp"
    
    # Replace REDACTED values with real ones from the real config
    yq eval-all '
        (select(fileIndex == 0) | .. | select(. == "REDACTED_BASE64")) =
        (select(fileIndex == 1) | getpath(path))
    ' "$TEMPLATE" "$REAL_CONFIG" > "$OUTPUT_FILE"
    
    rm -f "$OUTPUT_FILE.tmp"
    
elif command -v python3 &> /dev/null; then
    echo "Using Python for YAML processing..."
    
    python3 << 'PYTHON_SCRIPT'
import sys
import re

# Read both files
with open(sys.argv[1], 'r') as f:
    template = f.read()

with open(sys.argv[2], 'r') as f:
    real_config = f.read()

# Extract secrets from real config using regex
def extract_value(yaml_text, pattern):
    match = re.search(pattern, yaml_text, re.MULTILINE)
    return match.group(1) if match else None

# Machine token
machine_token = extract_value(real_config, r'^\s*token:\s*([a-z0-9]{6}\.[a-z0-9]{16})')
if machine_token:
    template = re.sub(r'token:\s*REDACTED_TOKEN', f'token: {machine_token}', template)

# Machine CA cert
machine_ca_crt = extract_value(real_config, r'machine:\s*\n.*?ca:\s*\n.*?crt:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if machine_ca_crt:
    template = re.sub(r'(machine:.*?ca:.*?crt:\s*)REDACTED_BASE64', f'\\1{machine_ca_crt}', template, flags=re.DOTALL)

# Machine CA key
machine_ca_key = extract_value(real_config, r'machine:.*?ca:.*?key:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if machine_ca_key:
    template = re.sub(r'(machine:.*?ca:.*?key:\s*)REDACTED_BASE64', f'\\1{machine_ca_key}', template, flags=re.DOTALL)

# Cluster ID
cluster_id = extract_value(real_config, r'cluster:\s*\n.*?id:\s*([A-Za-z0-9+/=_-]{20,})')
if cluster_id:
    template = re.sub(r'id:\s*REDACTED_ID', f'id: {cluster_id}', template)

# Cluster secret
cluster_secret = extract_value(real_config, r'cluster:.*?secret:\s*([A-Za-z0-9+/=]{20,})')
if cluster_secret:
    template = re.sub(r'secret:\s*REDACTED_SECRET', f'secret: {cluster_secret}', template, count=1)

# Bootstrap token
bootstrap_token = extract_value(real_config, r'cluster:.*?token:\s*([a-z0-9]{6}\.[a-z0-9]{16})')
if bootstrap_token:
    template = re.sub(r'(cluster:.*?token:\s*)REDACTED_TOKEN', f'\\1{bootstrap_token}', template, flags=re.DOTALL)

# Secretbox encryption secret
secretbox = extract_value(real_config, r'secretboxEncryptionSecret:\s*([A-Za-z0-9+/=]{20,})')
if secretbox:
    template = re.sub(r'secretboxEncryptionSecret:\s*REDACTED_SECRET', f'secretboxEncryptionSecret: {secretbox}', template)

# AESCBC encryption secret
aescbc = extract_value(real_config, r'aescbcEncryptionSecret:\s*([A-Za-z0-9+/=]{20,})')
if aescbc:
    template = re.sub(r'aescbcEncryptionSecret:\s*REDACTED_SECRET', f'aescbcEncryptionSecret: {aescbc}', template)

# Kubernetes CA
k8s_ca_crt = extract_value(real_config, r'cluster:.*?ca:.*?crt:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if k8s_ca_crt:
    template = re.sub(r'(cluster:.*?ca:.*?crt:\s*)REDACTED_BASE64', f'\\1{k8s_ca_crt}', template, flags=re.DOTALL)

# Kubernetes CA key
k8s_ca_key = extract_value(real_config, r'cluster:.*?ca:.*?key:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if k8s_ca_key:
    template = re.sub(r'(cluster:.*?ca:.*?key:\s*)REDACTED_BASE64', f'\\1{k8s_ca_key}', template, flags=re.DOTALL)

# Aggregator CA
agg_ca_crt = extract_value(real_config, r'aggregatorCA:.*?crt:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if agg_ca_crt:
    template = re.sub(r'(aggregatorCA:.*?crt:\s*)REDACTED_BASE64', f'\\1{agg_ca_crt}', template, flags=re.DOTALL)

# Aggregator CA key
agg_ca_key = extract_value(real_config, r'aggregatorCA:.*?key:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if agg_ca_key:
    template = re.sub(r'(aggregatorCA:.*?key:\s*)REDACTED_BASE64', f'\\1{agg_ca_key}', template, flags=re.DOTALL)

# Service account key
sa_key = extract_value(real_config, r'serviceAccount:.*?key:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if sa_key:
    template = re.sub(r'(serviceAccount:.*?key:\s*)REDACTED_BASE64', f'\\1{sa_key}', template, flags=re.DOTALL)

# Etcd CA
etcd_ca_crt = extract_value(real_config, r'etcd:.*?ca:.*?crt:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if etcd_ca_crt:
    template = re.sub(r'(etcd:.*?ca:.*?crt:\s*)REDACTED_BASE64', f'\\1{etcd_ca_crt}', template, flags=re.DOTALL)

# Etcd CA key
etcd_ca_key = extract_value(real_config, r'etcd:.*?ca:.*?key:\s*(LS0tLS[A-Za-z0-9+/=]+)')
if etcd_ca_key:
    template = re.sub(r'(etcd:.*?ca:.*?key:\s*)REDACTED_BASE64', f'\\1{etcd_ca_key}', template, flags=re.DOTALL)

# Write output
with open(sys.argv[3], 'w') as f:
    f.write(template)

print("✅ Secrets merged successfully!")

PYTHON_SCRIPT "$TEMPLATE" "$REAL_CONFIG" "$OUTPUT_FILE"

else
    echo "Error: Neither yq nor python3 found. Please install one of them."
    echo ""
    echo "Install yq: brew install yq"
    echo "  or"
    echo "Python should be available by default on macOS"
    exit 1
fi

echo ""
echo "✅ Merge complete!"
echo ""
echo "Output file: $OUTPUT_FILE"
echo "Template used: $TEMPLATE"
echo ""
echo "⚠️  IMPORTANT: This file contains REAL SECRETS!"
echo "   - Do NOT commit this file to Git"
echo "   - Store it securely (encrypted backup, password manager, etc.)"
echo "   - Use it to recreate nodes if needed"
echo ""
echo "To use this config:"
echo "  talosctl apply-config --insecure --nodes <NODE_IP> --file $OUTPUT_FILE"
