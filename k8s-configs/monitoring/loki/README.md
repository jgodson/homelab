### Loki Setup Steps

1. **Create MinIO buckets for Loki**
   
   Loki requires three separate buckets: `chunks`, `ruler`, and `admin`. You can create these in the MinIO UI:
   - Open the MinIO Console at http://minio.local or your configured URL
   - Navigate to "Buckets" in the sidebar
   - Click "Create Bucket" and create each of the following buckets:
     - `chunks` (for storing log chunks)
     - `ruler` (for storing ruler configurations)
     - `admin` (for administrative data)

2. **Create MinIO credentials secret**
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