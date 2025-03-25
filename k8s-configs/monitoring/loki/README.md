### Steps
1. Create secret (`Loki Minio` in 1Password)
2. Install helm chart
    ```bash
    helm install loki grafana/loki -f values.yaml -n monitoring
    ```
3. You can test ingesting with the following:
    ```bash
    curl -k -H "Content-Type: application/json" -XPOST -s "https://loki.home.jasongodson.com/loki/api/v1/push"  \
    --data-raw "{\"streams\": [{\"stream\": {\"job\": \"test\"}, \"values\": [[\"$(date +%s)000000000\", \"fizzbuzz\"]]}]}"
    ```
4. You can test querying with the following:
    ```bash
    curl -k "https://loki.home.jasongodson.com/loki/api/v1/query_range" \
    --data-urlencode "query={job=\"test\"}" \
    --data-urlencode "start=$(date -v -1H +%s)000000000" \
    --data-urlencode "end=$(date +%s)000000000" \
    --data-urlencode "limit=100" | jq .
    ```