1. Apply metrics-server.yaml `kubectl apply -f metrics-server.yaml`
1. Make sure Caddy & Adguard are running with Docker. [See readme](../../docker/ingress-local+adguard/README.md)
1. Make sure metallb is already deployed since Traefik needs a LoadBalancer. [See readme](../metallb/README.md)
1. Make sure Traefik is already deployed as the rest rely on it. [See readme](../traefik/README.md)
1. Create kubernetes namespace `kubectl create namespace monitoring`
1. Deploy and setup InfluxDB2 with Helm. [See readme](./influxdb2/README.md)
1. Deploy Prometheus with Helm. [See readme](./prometheus/README.md)
1. Ensure Minio is running with Docker (for Loki). [See readme](../../docker/minio/README.md)
1. Deploy Loki with Helm. [See readme](./loki/README.md)
    - See [observability config readme](../../observability-config/README.md) for how to start sending logs to Loki.
1. Deploy Tempo with Helm for distributed tracing. [See readme](./tempo/README.md)
1. Deploy Grafana Alloy with Helm for unified telemetry collection. [See readme](./alloy/README.md)
1. Deploy Grafana with Helm. [See readme](./grafana/README.md)
    - Remember to add Tempo as a data source in Grafana after setup