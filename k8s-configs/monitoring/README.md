1. Make sure metallb is already deployed since the following rely on a LoadBalancer
1. Make sure traefik is already deployed as it also relies on that
1. Create namespace `kubectl create namespace monitoring`
1. Deploy and setup Influxdb2 with helm. [See readme](./influxdb2/README.md)
1. Deploy Prometheus. [See readme](./prometheus/README.md)