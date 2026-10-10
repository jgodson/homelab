#!/usr/bin/env bash
# Stores the Grafana MCP server's credentials and registers it with Claude Code.
#
# Before running: in Grafana, create a service account with the Editor role
# (Administration > Users and access > Service accounts), add a token, and copy it.
# The script reads the token from the clipboard, or asks for it at a hidden prompt,
# so it never appears on screen.
# Re-run it to rotate both tokens.
set -euo pipefail

NAMESPACE=monitoring
SECRET=grafana-mcp
MCP_URL=https://grafana-mcp.home.jasongodson.com/mcp

grafana_token="$(pbpaste | tr -d '[:space:]')"
if [[ "$grafana_token" != glsa_* && -t 0 ]]; then
  read -rsp "Paste the Grafana service account token (input hidden): " grafana_token
  echo
  grafana_token="$(tr -d '[:space:]' <<<"$grafana_token")"
fi
if [[ "$grafana_token" != glsa_* ]]; then
  echo "That isn't a Grafana service account token (glsa_...). Copy it and re-run." >&2
  exit 1
fi
server_token="$(openssl rand -hex 32)"

kubectl -n "$NAMESPACE" create secret generic "$SECRET" \
  --from-literal=grafana-token="$grafana_token" \
  --from-literal=server-token="$server_token" \
  --dry-run=client -o yaml | kubectl apply -f -

# The server token is read from an env var at startup, so restart to pick up a new one.
kubectl -n "$NAMESPACE" rollout restart deployment/grafana-mcp
kubectl -n "$NAMESPACE" rollout status deployment/grafana-mcp --timeout=120s

claude mcp remove grafana --scope user >/dev/null 2>&1 || true
claude mcp add --scope user --transport http grafana "$MCP_URL" \
  --header "Authorization: Bearer $server_token"

printf '' | pbcopy
echo "Done. Clipboard cleared. Start a new Claude Code session to load the grafana MCP server."
