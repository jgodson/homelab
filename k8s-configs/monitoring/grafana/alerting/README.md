# Grafana Alerting

This directory is the source of truth for homelab-wide Grafana alerting resources.

Use this directory for:

- global contact points
- the notification policy tree
- generic infrastructure alert rule groups

Do not commit personal email addresses or other private notification targets here. This repo is public.

## Files

- `contact-point.template.json`
- `policies.template.json`
- `rule-groups/*.json`
- `apply-alerting.sh`

## Placeholders

The template files use `__ALERT_EMAIL__` as a placeholder so the committed files stay public-safe.

Render them locally before applying, for example:

```bash
sed 's/__ALERT_EMAIL__/alerts@example.com/g' k8s-configs/monitoring/grafana/alerting/contact-point.template.json
```

`apply-alerting.sh` does that replacement for you when you pass `ALERT_EMAIL`. The live Grafana receiver name will also use that value.

## Apply

The script reads Grafana credentials from the `grafana-admin-credentials` Kubernetes secret by default and opens a temporary port-forward to the in-cluster Grafana Service.

```bash
ALERT_EMAIL='alerts@example.com' \
bash k8s-configs/monitoring/grafana/alerting/apply-alerting.sh
```

Optional overrides:

- `GRAFANA_URL`
- `GRAFANA_USER`
- `GRAFANA_PASSWORD`
- `GRAFANA_NAMESPACE`
- `GRAFANA_SERVICE`
- `GRAFANA_PORT_FORWARD_PORT`

## Notes

- The script uses Grafana's alerting provisioning API, not file provisioning.
- It sends `X-Disable-Provenance: true` so these resources remain editable in the UI.
- Re-applying `policies.template.json` replaces the entire notification policy tree, so review that file before applying changes.
