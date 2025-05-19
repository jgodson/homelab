### Tempo Distributed Setup

1. **Create MinIO bucket for Tempo**
   
   Tempo requires a single bucket to store trace data:
   - Open the MinIO Console at http://192.168.1.252:9001 or your configured URL
   - Navigate to "Buckets" in the sidebar
   - Click "Create Bucket" and create a bucket named `tempo`
   - No special bucket policies are needed for basic functionality

2. **Create MinIO credentials secret**
   ```bash
   kubectl create secret generic tempo-minio-credentials \
     --from-literal=MINIO_ACCESS_KEY=your-access-key \
     --from-literal=MINIO_SECRET_KEY=your-secret-key \
     -n monitoring
   ```
   Or use an existing secret from 1Password.

3. **Install Tempo Distributed with Helm**
   ```bash
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo update
   helm install tempo grafana/tempo-distributed -f values.yaml -n monitoring
   ```

4. **Configure Grafana to use Tempo**
   
   Add the following data source in Grafana (this can be added to your `values.yaml` for the Grafana Helm chart or configured via the UI):
   ```yaml
   - name: Tempo
     type: tempo
     access: proxy
     orgId: 1
     url: http://tempo-query-frontend.monitoring.svc.cluster.local:3100
     basicAuth: false
     isDefault: false
     version: 1
     editable: true
     uid: tempo
     jsonData:
       httpMethod: GET
       tracesToLogs:
         datasourceUid: loki
         tags: ['job', 'instance', 'pod', 'namespace']
         mappedTags: [{ key: 'service.name', value: 'container' }]
         mapTagNamesEnabled: false
         spanStartTimeShift: '-1h'
         spanEndTimeShift: '1h'
         filterByTraceID: true
       serviceMap:
         datasourceUid: prometheus
       nodeGraph:
         enabled: true
   ```

5. **Test sending traces**
   
   You can test sending traces to Tempo using the OTLP endpoint. First, set up port forwarding to access the Tempo distributor service from your local machine:
   
   ```bash
   kubectl -n monitoring port-forward svc/tempo-distributor 3100:3100
   ```

   Then you can send a test trace to Tempo:

   ```bash
   curl -X POST http://localhost:3100/v1/traces -H "Content-Type: application/json" -d '{
     "resourceSpans": [
       {
         "resource": {
           "attributes": [
             {
               "key": "service.name",
               "value": { "stringValue": "test-service" }
             }
           ]
         },
         "scopeSpans": [
           {
             "scope": {},
             "spans": [
               {
                 "traceId": "0123456789abcdef0123456789abcdef",
                 "spanId": "0123456789abcdef",
                 "name": "test-span",
                 "kind": 1,
                 "startTimeUnixNano": "1628847222000000000",
                 "endTimeUnixNano": "1628847222100000000",
                 "attributes": []
               }
             ]
           }
         ]
       }
     ]
   }'
   ```

6. **Access in Grafana**
   
   Once traces are flowing into Tempo, you can query them in Grafana:
   - Navigate to Explore
   - Select the Tempo data source
   - Search for traces by service name or trace ID
   - View trace details and related logs if you've configured the tracesToLogs section

7. **Service Graphs & Span Metrics**

   The distributed setup includes the metrics generator component which automatically creates:
   
   - **Service graphs**: Visualize the relationships between services
   - **RED metrics**: Request rate, error rate, and duration metrics derived from spans

   To view service graphs in Grafana:
   - Go to Explore
   - Select the Tempo data source
   - Click on the "Service Graph" tab
   
   You can also create dashboards using the metrics generated in Prometheus with metrics like:
   - `tempo_spanmetrics_*`
   - `tempo_service_graph_*`

8. **Component Architecture**

   This distributed setup includes the following components:
   
   - **Distributor**: Receives and distributes traces
   - **Ingester**: Batches trace data for writing to object storage
   - **Querier**: Handles trace search and retrieval
   - **Query-Frontend**: Optimizes and routes queries
   - **Compactor**: Compacts trace data for efficient storage
   - **Metrics-Generator**: Generates metrics from trace data