#!/bin/bash
# Deploy SSH-based VM disk monitoring with Telegraf

set -e

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Deploying SSH-based VM Disk Monitoring"
echo "========================================"

# Check if SSH key exists (created by Ansible playbook)
SSH_KEY_PATH="$HOME/.ssh/telegraf_monitoring"
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "❌ SSH key not found at $SSH_KEY_PATH"
    echo "   Run the Ansible setup playbook first:"
    echo "   cd ~/Documents/github/homelab-automation/ansible"
    echo "   ansible-playbook -i inventory/production.yml playbooks/setup-telegraf-ssh.yml"
    exit 1
fi

echo "✅ Found SSH key at $SSH_KEY_PATH"

# Create or update the scripts ConfigMap
echo "📝 Creating/updating scripts ConfigMap..."
kubectl create configmap telegraf-scripts \
    --from-file=collect-vm-disk-usage.sh="$SCRIPT_DIR/collect-vm-disk-usage.sh" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create VM hosts ConfigMap only if it does NOT already exist (avoid clobbering user edits)
VM_HOSTS_MANIFEST="$SCRIPT_DIR/telegraf-vm-hosts-configmap.yaml"
if kubectl get configmap telegraf-vm-hosts -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✅ VM hosts ConfigMap already exists (not modifying)"
else
    if [[ -f "$VM_HOSTS_MANIFEST" ]]; then
        echo "🗂  Creating VM hosts ConfigMap from manifest (initial setup)..."
        kubectl apply -f "$VM_HOSTS_MANIFEST"
    else
        echo "⚠️  VM hosts manifest not found at $VM_HOSTS_MANIFEST"
        echo "    Create it (see README.md) or collection will report status=vm_list_missing only."
    fi
fi

# Basic validation: ensure at least one non-comment host entry will be present after apply
if kubectl get configmap telegraf-vm-hosts -n "$NAMESPACE" >/dev/null 2>&1; then
    TMP_HOSTS=$(mktemp)
    kubectl get configmap telegraf-vm-hosts -n "$NAMESPACE" -o jsonpath='{.data.hosts}' > "$TMP_HOSTS" || true
    if ! grep -Eq '^[[:space:]]*[^#[:space:]][^:]+:[0-9]' "$TMP_HOSTS"; then
         echo "❌ No valid host entries found in telegraf-vm-hosts ConfigMap (key 'hosts')."
         echo "   Add lines of the form name:ip to $VM_HOSTS_MANIFEST (or edit the ConfigMap) and redeploy."
         rm -f "$TMP_HOSTS"
         exit 1
    fi
    echo "✅ VM hosts ConfigMap contains entries:" 
    grep -E '^[[:space:]]*[^#[:space:]][^:]+:[0-9]' "$TMP_HOSTS" | sed 's/^/   - /'
    rm -f "$TMP_HOSTS"
else
    echo "❌ telegraf-vm-hosts ConfigMap not present; aborting."
    exit 1
fi

# Check if SSH key secret exists
if kubectl get secret telegraf-ssh-key -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✅ SSH key secret already exists"
else
    echo "🔑 Creating SSH key secret..."
    kubectl create secret generic telegraf-ssh-key \
        --from-file=id_rsa="$SSH_KEY_PATH" \
        -n "$NAMESPACE"
fi

# Check if InfluxDB credentials secret exists
if kubectl get secret telegraf-influxdb-credentials -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "✅ InfluxDB credentials secret already exists"
else
    echo "❌ InfluxDB credentials secret not found!"
    echo "   Make sure telegraf-influxdb-credentials secret exists with influx-token and influx-org"
    exit 1
fi

echo "🔄 Deploying Telegraf with SSH monitoring..."
helm upgrade --install telegraf-ssh influxdata/telegraf \
    -f values.yaml \
    -n "$NAMESPACE"

echo "⏳ Waiting for Telegraf to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=telegraf-ssh -n "$NAMESPACE" --timeout=60s

echo "🎉 Deployment complete!"
echo
echo "� Testing SSH collection..."
if kubectl exec -n "$NAMESPACE" deployment/telegraf-ssh -- sh -c 'VM_LIST_FILE=/config/vms/hosts /scripts/collect-vm-disk-usage.sh' 2>&1 | grep -q '"measurement"'; then
    echo "✅ SSH collection test successful!"
else
    echo "⚠️  SSH collection test did not return expected data"
    echo "   Check logs for details"
fi
echo
echo "📊 To check logs:"
echo "kubectl logs -n $NAMESPACE deployment/telegraf-ssh --tail=20"
echo
echo "📈 Check your InfluxDB for new measurements:"
echo "- vm_disk_usage (disk usage by VM)"  
echo "- vm_system_usage (memory and load by VM)"
echo