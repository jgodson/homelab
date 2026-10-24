### Loki Setup Steps

1. **Garage buckets for Loki**

   Loki uses three buckets in Garage: `chunks` (log chunks and TSDB index), `ruler`, and `admin`. They and the `observability` key's grants are managed in `homelab-automation` (`tofu/garage-buckets.tf`). Loki and Tempo share the `observability` key.

2. **Create the credentials secret** (it keeps its pre-Garage name)
   ```bash
   kubectl create secret generic loki-minio-credentials \
     --from-literal=MINIO_ACCESS_KEY=your-access-key \
     --from-literal=MINIO_SECRET_KEY=your-secret-key \
     -n monitoring
   ```
   Or use an existing secret from 1Password.

3. **Install Helm chart**
   ```bash
   helm install loki grafana/loki -f values.yaml -n monitoring
   ```

4. **Test log ingestion**
   ```bash
   curl -k -H "Content-Type: application/json" -XPOST -s "https://loki.home.jasongodson.com/loki/api/v1/push" \
   --data-raw "{\"streams\": [{\"stream\": {\"job\": \"test\"}, \"values\": [[\"$(date +%s)000000000\", \"fizzbuzz\"]]}]}"
   ```

5. **Test log querying**
   ```bash
   curl -k "https://loki.home.jasongodson.com/loki/api/v1/query_range" \
   --data-urlencode "query={job=\"test\"}" \
   --data-urlencode "start=$(date -v -1H +%s)000000000" \
   --data-urlencode "end=$(date +%s)000000000" \
   --data-urlencode "limit=100" | jq .
   ```

6. **Access in Grafana**
   - Logs from Loki should now be accessible in Grafana using the Loki data source.