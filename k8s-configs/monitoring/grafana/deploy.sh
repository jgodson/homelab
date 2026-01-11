#!/bin/bash

NAMESPACE="monitoring"
RELEASE_NAME="grafana"
CHART_NAME="grafana/grafana"
EMAIL_SECRET_NAME="grafana-email"
EMAIL_KEY="from_address"

# Pull from_address from the Kubernetes Secret
FROM_EMAIL=$(kubectl get secret "$EMAIL_SECRET_NAME" \
  -n "$NAMESPACE" \
  -o "jsonpath={.data.${EMAIL_KEY}}" | base64 --decode)

if [ -z "$FROM_EMAIL" ]; then
  echo "❌ Could not retrieve from_address from secret '$EMAIL_SECRET_NAME'"
  exit 1
fi

echo "📧 Using from_address: $FROM_EMAIL"

helm upgrade --install "$RELEASE_NAME" "$CHART_NAME" \
  -n "$NAMESPACE" \
  -f grafana-values.yaml \
  --set "grafana.grafana.ini.smtp.from_address=${FROM_EMAIL}"
