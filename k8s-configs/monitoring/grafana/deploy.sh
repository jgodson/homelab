#!/bin/bash

NAMESPACE="monitoring"
RELEASE_NAME="grafana"
CHART_NAME="grafana/grafana"
EMAIL_SECRET_NAME="grafana-email"

# Grafana reads the alert from_address from this secret (GF_SMTP_FROM_ADDRESS in values.yaml).
if ! kubectl get secret "$EMAIL_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "❌ Secret '$EMAIL_SECRET_NAME' with key 'from_address' not found in namespace '$NAMESPACE'"
  exit 1
fi

helm upgrade --install "$RELEASE_NAME" "$CHART_NAME" \
  -n "$NAMESPACE" \
  -f values.yaml
