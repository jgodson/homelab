#!/bin/bash
#
# encode-talosconfig.sh - Encode talosconfig for Gitea secrets
#
# This encodes your talosconfig file (client authentication) for use
# in Gitea Actions workflows as the TALOSCONFIG secret.
#
# Usage: ./encode-talosconfig.sh [path-to-talosconfig]
#

set -e

# Default to standard location
TALOSCONFIG_PATH="${1:-$HOME/.talos/config}"

if [ ! -f "$TALOSCONFIG_PATH" ]; then
    echo "❌ Error: Talosconfig not found at: $TALOSCONFIG_PATH"
    echo ""
    echo "Usage: $0 [path-to-talosconfig]"
    echo "Default: ~/.talos/config"
    exit 1
fi

echo "🔧 Encoding talosconfig for Gitea secrets..."
echo ""
echo "Source: $TALOSCONFIG_PATH"
echo ""

# Base64 encode the file
ENCODED=$(cat "$TALOSCONFIG_PATH" | base64)

echo "✅ Encoded successfully!"
echo ""
echo "📋 Copy this value to your Gitea repository secret 'TALOSCONFIG':"
echo ""
echo "---BEGIN ENCODED TALOSCONFIG---"
echo "$ENCODED"
echo "---END ENCODED TALOSCONFIG---"
echo ""
echo "🔐 To add to Gitea:"
echo "   1. Go to your repository → Settings → Secrets"
echo "   2. Add new secret named: TALOSCONFIG"
echo "   3. Paste the encoded value above"
echo ""
echo "💡 This is the CLIENT config (not machine config)"
echo "   - Used to authenticate talosctl and kubectl commands"
echo "   - Safe to use in CI/CD workflows"
echo "   - Different from the machine config (controlplane-config.yaml)"
