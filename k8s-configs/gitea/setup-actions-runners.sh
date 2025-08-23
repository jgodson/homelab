#!/bin/bash

# Gitea Actions Runner Setup Script
# This script sets up Gitea Actions runners for CI/CD automation
# Requires privileged namespace (configured in namespace.yaml) for Docker-in-Docker

set -e

echo "🏃‍♂️ Setting up Gitea Actions Runners..."

# Check if we're in the right directory
if [[ ! -f "actions-runner-values.yaml" ]]; then
    echo "❌ Error: Please run this script from the gitea directory"
    echo "Expected to find actions-runner-values.yaml in current directory"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
echo "🔍 Checking required tools..."
for tool in kubectl helm; do
    if ! command_exists $tool; then
        echo "❌ Error: $tool is not installed"
        exit 1
    fi
done
echo "✅ Required tools found"

# Check if Gitea is running
echo "🔍 Checking Gitea..."
if ! kubectl get deployment gitea -n gitea >/dev/null 2>&1; then
    echo "❌ Error: Gitea deployment not found in gitea namespace"
    echo "Please ensure Gitea is running first"
    exit 1
fi
echo "✅ Gitea found"

# Check for runner token secret
echo "🔐 Checking for runner token secret..."
if ! kubectl get secret gitea-runner-token -n gitea >/dev/null 2>&1; then
    echo "❌ Error: gitea-runner-token secret not found in gitea namespace"
    echo ""
    echo "📋 To create the runner token:"
    echo "1. Visit https://gitea.home.jasongodson.com"
    echo "2. Go to Admin Panel → Actions → Runners"
    echo "3. Generate a new registration token"
    echo "4. Create the secret with:"
    echo "   kubectl create secret generic gitea-runner-token -n gitea \\"
    echo "     --from-literal=token='<REGISTRATION_TOKEN>'"
    echo ""
    exit 1
fi
echo "✅ Runner token secret found"

# Clone Gitea Actions chart if not present
if [[ ! -d "/tmp/gitea-actions-chart" ]]; then
    echo "📥 Downloading Gitea Actions chart..."
    git clone https://gitea.com/gitea/helm-actions.git /tmp/gitea-actions-chart
else
    echo "📥 Updating Gitea Actions chart..."
    cd /tmp/gitea-actions-chart
    git pull
    cd - >/dev/null
fi

# Install Actions runners
echo "🏗️  Installing Gitea Actions runners..."
helm upgrade --install gitea-actions /tmp/gitea-actions-chart \
    -n gitea \
    -f actions-runner-values.yaml

echo ""
echo "🎉 Gitea Actions runners installation completed!"
echo ""
echo "⏳ Waiting for runners to be ready..."

# Wait for StatefulSet to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=actions -n gitea --timeout=300s

echo ""
echo "✅ Actions runners are ready!"
echo ""
echo "📋 Runner Information:"
kubectl get pods -n gitea -l app.kubernetes.io/name=actions
echo ""
echo "🔗 Next steps:"
echo "   1. Visit https://gitea.home.jasongodson.com/user/settings/actions/runners"
echo "   2. Verify runners are registered and online"
echo "   3. Create a repository with GitHub Actions workflows"
echo "   4. Test automation with your Ansible playbooks"
echo ""
echo "🏷️  Available runner labels:"
echo "   • self-hosted"
echo "   • kubernetes" 
echo "   • linux"
echo "   • x64"
echo "   • ansible"
