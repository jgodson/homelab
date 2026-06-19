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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    TEMPLATE="$SCRIPT_DIR/worker-config.yaml"
else
    TEMPLATE="$SCRIPT_DIR/controlplane-config.yaml"
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

if command -v ruby &> /dev/null; then
    echo "Using Ruby for path-aware YAML processing..."

    ruby - "$TEMPLATE" "$REAL_CONFIG" "$OUTPUT_FILE" << 'RUBY_SCRIPT'
require "yaml"

template_path, real_config_path, output_path = ARGV
placeholders = [
  "REDACTED_BASE64",
  "REDACTED_ID",
  "REDACTED_SECRET",
  "REDACTED_TOKEN"
].freeze

template = YAML.load_file(template_path)
real_config = YAML.load_file(real_config_path)
replacements = []
missing = []

format_path = lambda do |path|
  path.reduce("") do |memo, part|
    if part.is_a?(Integer)
      "#{memo}[#{part}]"
    elsif memo.empty?
      part.to_s
    else
      "#{memo}.#{part}"
    end
  end
end

merge_redacted = lambda do |template_value, real_value, path|
  case template_value
  when Hash
    template_value.each_with_object({}) do |(key, value), merged|
      next_real = real_value.is_a?(Hash) ? real_value[key] : nil
      merged[key] = merge_redacted.call(value, next_real, path + [key])
    end
  when Array
    template_value.each_with_index.map do |value, index|
      next_real = real_value.is_a?(Array) ? real_value[index] : nil
      merge_redacted.call(value, next_real, path + [index])
    end
  else
    if placeholders.include?(template_value)
      if real_value.nil? || placeholders.include?(real_value)
        missing << format_path.call(path)
        template_value
      else
        replacements << format_path.call(path)
        real_value
      end
    else
      template_value
    end
  end
end

merged = merge_redacted.call(template, real_config, [])

unless missing.empty?
  warn "Error: real config does not contain non-redacted values for:"
  missing.each { |path| warn "  - #{path}" }
  exit 1
end

yaml = YAML.dump(merged).sub(/\A---\s*\n/, "")
File.write(output_path, yaml)

puts "Merged #{replacements.length} redacted values."
RUBY_SCRIPT
else
    echo "Error: ruby was not found."
    echo ""
    echo "Ruby is used here so redacted values are replaced by exact YAML path"
    echo "instead of fragile text matching."
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
