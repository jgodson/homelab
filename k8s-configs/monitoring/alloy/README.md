### Grafana Alloy Setup Steps

Grafana Alloy is a central collector that can process both logs and traces through the same endpoint, using the OpenTelemetry Protocol (OTLP). This enables you to have a single ingestion point for all your telemetry data.

#### Prerequisites

1. Ensure Loki and Tempo are already deployed in your Kubernetes cluster
2. If sending logs from the public internet, ensure [ingress-public](../../../docker/ingress-public/) is set up and you have a username and password ready for basic auth.

#### Installation

1. Install Grafana Alloy with Helm:
   ```bash
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo update
   helm upgrade --install alloy grafana/alloy -f values.yaml -n monitoring
   ```

#### Usage

Alloy accepts OTLP data via:
- gRPC on port 4317
- HTTP on port 4318

#### OTLP-Compatible Libraries

The following libraries and frameworks support sending telemetry data using the OpenTelemetry Protocol (OTLP):

##### Official OpenTelemetry SDKs
- [OpenTelemetry JavaScript](https://github.com/open-telemetry/opentelemetry-js)
- [OpenTelemetry Python](https://github.com/open-telemetry/opentelemetry-python)
- [OpenTelemetry Java](https://github.com/open-telemetry/opentelemetry-java)
- [OpenTelemetry Go](https://github.com/open-telemetry/opentelemetry-go)
- [OpenTelemetry Ruby](https://github.com/open-telemetry/opentelemetry-ruby)
- [OpenTelemetry .NET](https://github.com/open-telemetry/opentelemetry-dotnet)
- [OpenTelemetry Rust](https://github.com/open-telemetry/opentelemetry-rust)
- [OpenTelemetry PHP](https://github.com/open-telemetry/opentelemetry-php)

##### Language-specific Instrumentation
- Ruby: [opentelemetry-instrumentation-rails](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation/rails)
- Python: [Flask instrumentation](https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/flask/flask.html)
- JavaScript: [Express middleware](https://github.com/open-telemetry/opentelemetry-js-contrib/tree/main/plugins/node/opentelemetry-instrumentation-express)
- Java: [Spring Boot starter](https://github.com/open-telemetry/opentelemetry-java-instrumentation/tree/main/instrumentation/spring/spring-boot-autoconfigure)
- Go: [Echo instrumentation](https://github.com/open-telemetry/opentelemetry-go-contrib/tree/main/instrumentation/github.com/labstack/echo)

##### Log Collectors/Agents
- [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) - The reference implementation for collecting, processing, and exporting telemetry data
- [Vector](https://vector.dev/) - High-performance observability data pipeline with OTLP support
- [Fluentd OpenTelemetry plugin](https://github.com/fluent/fluent-plugin-opentelemetry) - Send logs from Fluentd to OpenTelemetry compatible backends

#### Testing Functionality

#### Verify Metrics:

##### 1. Test Local Connectivity First

Before testing through the public internet, first verify that you can reach the Alloy service through your internal network:

```bash
# Test connectivity through the local ingress
# From a machine that can resolve alloy.home.jasongodson.com
curl -i https://alloy.home.jasongodson.com/v1/metrics \
  -H "Content-Type: application/json" \
  -d "{\"resourceMetrics\":[{\"resource\":{\"attributes\":[{\"key\":\"service_name\",\"value\":{\"stringValue\":\"test-service\"}}]},\"scopeMetrics\":[{\"metrics\":[{\"name\":\"test_metric\",\"gauge\":{\"dataPoints\":[{\"asDouble\":1.0,\"timeUnixNano\":\"$(date +%s)000000000\"}]}}]}]}]}"
```

Note that we're using port 80 (default HTTP port) instead of 4318 because the request will go through the reverse proxy to the correct port.

You shoul get a 200 response with a body of `{"partialSuccess":{}}`. If this fails, then get it working before moving onto the public internet portion.

##### 2. Test Public Internet Access with Basic Authentication

Once local connectivity is confirmed, verify authentication is working through the public endpoint:

```bash
# Replace with your actual username and password
# This command uses the current timestamp in nanoseconds
curl -i -u "username:password" https://telemetry.jasongodson.com/v1/metrics \
  -H "Content-Type: application/json" \
  -d "{\"resourceMetrics\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"test-service\"}}]},\"scopeMetrics\":[{\"metrics\":[{\"name\":\"test.metric\",\"gauge\":{\"dataPoints\":[{\"asDouble\":1.0,\"timeUnixNano\":\"$(date +%s)000000000\"}]}}]}]}]}"
```

For a successful request, you should receive a response with status code 200 and the `{"partialSuccess":{}}` body. If authentication fails, you'll see a 401 status code. If you see a 502 error, there's likely a connectivity issue between the public ingress and the Alloy service.

Check that metrics are appearing in Prometheus by querying for your service name or `{processed_by = "alloy"}` in Grafana.

#### Verify Logs:

1. Send a test log via the Alloy HTTP endpoint:

   ```bash
   # Through your local ingress
   curl -s -H "Content-Type: application/json" -X POST \
     --data '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-log-service"}}]},"scopeLogs":[{"scope":{},"logRecords":[{"timeUnixNano":"'$(date +%s%N)'","body":{"stringValue":"Test log message"},"attributes":[{"key":"level","value":{"stringValue":"info"}},{"key":"hostname","value":{"stringValue":"test-host"}}]}]}]}]}' \
     https://alloy.home.jasongodson.com/v1/logs
   
   # Or through public endpoint with authentication
   curl -s -u "username:password" -H "Content-Type: application/json" -X POST \
     --data '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-log-service"}}]},"scopeLogs":[{"scope":{},"logRecords":[{"timeUnixNano":"'$(date +%s%N)'","body":{"stringValue":"Test log message"},"attributes":[{"key":"level","value":{"stringValue":"info"}},{"key":"hostname","value":{"stringValue":"test-host"}}]}]}]}]}' \
     https://telemetry.jasongodson.com/v1/logs
   ```

2. Verify in Grafana's Explore view that the log appears in Loki:
   
   ```
   {service_name="test-log-service"}
   ```

##### Hydrogen/Oxygen Shop-specific Logs

For Hydrogen applications, you can include specific attributes in your log queries:

```
{service_name="oxygen", shop_id="123"}
```

Commonly available Hydrogen attributes that can be used for filtering are listed [in the Shopify documentation](https://shopify.dev/docs/storefronts/headless/hydrogen/logging)

You can test Hydrogen-specific log attributes using:

```bash
curl -s -H "Content-Type: application/json" -X POST \
  --data '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"hydrogen-app"}}]},"scopeLogs":[{"scope":{},"logRecords":[{"timeUnixNano":"'$(date +%s%N)'","body":{"stringValue":"Test Hydrogen log"},"attributes":[{"key":"level","value":{"stringValue":"info"}},{"key":"hostname","value":{"stringValue":"test-host"}},{"key":"shop_id","value":{"stringValue":"my-shop-123"}},{"key":"storefront_id","value":{"stringValue":"sf-456"}},{"key":"deployment_id","value":{"stringValue":"deploy-789"}},{"key":"code","value":{"stringValue":"200"}}]}]}]}]}' \
  https://alloy.home.jasongodson.com/v1/logs
```

#### Verify Traces:

1. Send a test trace via the Alloy HTTP endpoint:

   ```bash
   # Generate a trace ID for tracking
   TRACE_ID=$(openssl rand -hex 16)
   
   # Through your local ingress
   curl -s -H "Content-Type: application/json" -X POST \
     --data '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-trace-service"}}]},"scopeSpans":[{"scope":{},"spans":[{"traceId":"'$TRACE_ID'","spanId":"'$(openssl rand -hex 8)'","name":"test-span","kind":1,"startTimeUnixNano":"'$(date +%s%N)'","endTimeUnixNano":"'$(date +%s%N)'","attributes":[{"key":"operation","value":{"stringValue":"test"}}]}]}]}]}' \
     https://alloy.home.jasongodson.com/v1/traces && echo "Trace ID: $TRACE_ID"
   
   # Or through public endpoint with authentication
   curl -s -u "username:password" -H "Content-Type: application/json" -X POST \
     --data '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-trace-service"}}]},"scopeSpans":[{"scope":{},"spans":[{"traceId":"'$TRACE_ID'","spanId":"'$(openssl rand -hex 8)'","name":"test-span","kind":1,"startTimeUnixNano":"'$(date +%s%N)'","endTimeUnixNano":"'$(date +%s%N)'","attributes":[{"key":"operation","value":{"stringValue":"test"}}]}]}]}]}' \
     https://telemetry.jasongodson.com/v1/traces && echo "Trace ID: $TRACE_ID"
   ```

2. Verify in Grafana's Explore view that the trace appears in Tempo:
   * Search by the generated Trace ID
   * Or search by service name: `test-trace-service`

##### Advanced Troubleshooting

For more in-depth troubleshooting using direct pod access:

1. Enable debug logging in your Alloy configuration:
   ```yaml
   logging {
     level = "debug"
     format = "logfmt"
   }
   ```

2. Check Alloy logs to verify it's receiving and processing telemetry:
   ```bash
   kubectl -n monitoring logs -l app.kubernetes.io/name=alloy --tail=100 | grep -i "log\|trace\|otlp"
   ```

3. Test directly to Loki for log delivery issues:
   ```bash
   # Port-forward to Loki query service
   kubectl -n monitoring port-forward svc/loki-read 3100:3100
   
   # In another terminal, use curl to query Loki
   curl -s "http://localhost:3100/loki/api/v1/query?query={service_name=\"test-log-service\"}" | jq
   
   # For a specific time range (last 1 hour)
   curl -s "http://localhost:3100/loki/api/v1/query_range?query={service_name=\"test-log-service\"}&start=$(date -v-1H +%s)000000000&end=$(date +%s)000000000" | jq
   ```

4. Validate trace ingestion by directly querying Tempo:
   ```bash
   # Port-forward to Tempo query service
   kubectl -n monitoring port-forward svc/tempo-query-frontend 3100:3100
   
   # In another terminal, query for the trace by ID
   curl -s "http://localhost:3100/api/traces/YOUR_TRACE_ID" | jq
   
   # To search for traces by service name
   curl -s "http://localhost:3100/api/search?tags=service.name%3Dyour-service-name&limit=20" | jq
   
   # To search for traces by specific attribute
   curl -s "http://localhost:3100/api/search?tags=http.target%3D%2Fapi%2Fendpoint&limit=10" | jq
   ```

### Trace-Log Correlation

Correlating logs with traces is a powerful way to understand the context of logs within a trace or to find all logs associated with a specific request. This can be done by default as long as the trace_id is present in the corresponding logs.

> **Note:** As of now, I haven't found a way to make trace-log correlation work seamlessly with Shopify Oxygen. However, this should be possible by configuring correlations in Grafana's **Correlations** feature. Further experimentation may be required to achieve full integration.

#### Testing Trace-Log Correlation

You can test the correlation by sending a log and trace with matching IDs:

```bash
# Generate a random trace ID for testing
TRACE_ID=$(openssl rand -hex 16)

# Send a trace with this ID
curl -s -H "Content-Type: application/json" -X POST \
  --data '{"resourceSpans":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-correlation"}}]},"scopeSpans":[{"scope":{},"spans":[{"traceId":"'$TRACE_ID'","spanId":"'$(openssl rand -hex 8)'","name":"test-span","kind":1,"startTimeUnixNano":"'$(date +%s%N)'","endTimeUnixNano":"'$(date +%s%N)'","attributes":[{"key":"request_id","value":{"stringValue":"abc-123"}}]}]}]}]}' \
  https://alloy.home.jasongodson.com/v1/traces

# Send a log with the same trace ID embedded in the log message
curl -s -H "Content-Type: application/json" -X POST \
  --data '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"test-correlation"}}]},"scopeLogs":[{"scope":{},"logRecords":[{"timeUnixNano":"'$(date +%s%N)'","body":{"stringValue":"Test log with trace_id: '$TRACE_ID'"},"attributes":[{"key":"level","value":{"stringValue":"info"}},{"key":"request_id","value":{"stringValue":"abc-123"}}]}]}]}]}' \
  https://alloy.home.jasongodson.com/v1/logs

echo "Test Trace ID: $TRACE_ID"
```

Once you've sent both a trace and log with the same ID, navigate to Grafana:

1. Go to Explore view
2. Select the Tempo datasource
3. Search for service name "test-correlation"
4. Click on the trace in the search results
5. Look for the "Logs for this trace" button or section
6. The query should find the log record associated with this trace ID