# Grafana MCP server

Runs Grafana's [mcp-grafana](https://github.com/grafana/mcp-grafana) so Claude Code can query Loki logs, Prometheus metrics, Tempo traces, dashboards and alert rules.

- Endpoint: `https://grafana-mcp.home.jasongodson.com/mcp` (streamable HTTP, LAN only)
- Anonymous usage reporting to Grafana Labs is off (`--usage-stats=disabled`).
- Write tools are enabled, but Grafana permissions limit what they can do: the service account has the Viewer role plus **Edit** on the Infrastructure dashboard folder only. Any other write (alert rules, other folders, admin) is rejected by Grafana.
- Callers must send `Authorization: Bearer <server-token>`.

## Setup

1. `make deploy-grafana-mcp`. The pod waits until the `grafana-mcp` secret exists.
2. In Grafana, create a service account with the **Viewer** role, add a token and copy it. To let it save dashboards, give it Edit on the folders it may change (Dashboards > folder > Folder actions > Manage permissions).
3. Run `./grafana-mcp/setup-secret.sh`. It reads the token from the clipboard (or a hidden prompt), generates the server token, stores both in the `grafana-mcp` secret, restarts the deployment and registers the server with Claude Code (user scope).

Re-run step 3 to rotate the tokens. Neither token is stored in git.
