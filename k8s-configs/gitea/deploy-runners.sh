#!/bin/bash

# Gitea Actions Runner Deployment Script
# This script deploys or updates the Gitea Actions runners in Kubernetes

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="gitea"
RELEASE_NAME="gitea-actions"
VALUES_FILE="$SCRIPT_DIR/actions-runner-values.yaml"
HELM_CHART_REPO="https://gitea.com/gitea/helm-actions.git"
TEMP_CHART_DIR="/tmp/helm-actions"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is required but not installed. Please install helm first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required but not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Unable to connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    if [ ! -f "$VALUES_FILE" ]; then
        log_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Download or update helm chart
update_helm_chart() {
    log_info "Updating Helm chart..."
    
    # Clean up any existing chart directory
    if [ -d "$TEMP_CHART_DIR" ]; then
        rm -rf "$TEMP_CHART_DIR"
    fi
    
    # Clone the latest chart
    git clone "$HELM_CHART_REPO" "$TEMP_CHART_DIR"
    
    log_success "Helm chart updated"
}

# Check if namespace exists, create if not
ensure_namespace() {
    log_info "Ensuring namespace '$NAMESPACE' exists..."
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' does not exist, creating..."
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace '$NAMESPACE' created"
    else
        log_info "Namespace '$NAMESPACE' already exists"
    fi
}

# Deploy or upgrade the release
deploy_release() {
    log_info "Deploying/upgrading Gitea Actions runners..."
    
    # Check if release exists
    if helm status "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        log_info "Release '$RELEASE_NAME' exists, upgrading..."
        helm upgrade "$RELEASE_NAME" "$TEMP_CHART_DIR" \
            -n "$NAMESPACE" \
            -f "$VALUES_FILE" \
            --timeout 300s
    else
        log_info "Release '$RELEASE_NAME' does not exist, installing..."
        helm install "$RELEASE_NAME" "$TEMP_CHART_DIR" \
            -n "$NAMESPACE" \
            -f "$VALUES_FILE" \
            --timeout 300s
    fi
    
    log_success "Deployment completed"
}

# Show deployment status
show_status() {
    log_info "Checking deployment status..."
    
    echo ""
    echo "=== Helm Release Status ==="
    helm status "$RELEASE_NAME" -n "$NAMESPACE"
    
    echo ""
    echo "=== Pod Status ==="
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=actions-act-runner
    
    echo ""
    echo "=== Runner Logs (last 10 lines) ==="
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=actions-act-runner --tail=10 || true
}

# Cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    if [ -d "$TEMP_CHART_DIR" ]; then
        rm -rf "$TEMP_CHART_DIR"
    fi
    log_success "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting Gitea Actions Runner deployment..."
    
    check_prerequisites
    update_helm_chart
    ensure_namespace
    deploy_release
    show_status
    cleanup
    
    log_success "Gitea Actions Runner deployment completed successfully!"
    echo ""
    log_info "Available runner labels:"
    echo "  - homelab-latest: docker://gitea.home.jasongodson.com/homelab/actions-runner:latest"
    echo "  - host-docker: host (for Docker builds)"
    echo ""
    log_info "Use 'kubectl get pods -n $NAMESPACE' to monitor the runners"
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@"
