### Steps
1. Create secret (`InfluxDb admin` in 1Password)
2. Install helm chart
    ```bash
    helm install influxdb influxdata/influxdb2 \
    -f ./influxdb2/values.yaml \
    -n monitoring
    ```
3. Apply the ingress file `kubectl apply -f ingress.yaml`
4. Log into the admin interface at influxdb.home.jasongodson.com
5. Create buckets (retenton `Forever`):
   - `homeassistant` - For Home Assistant metrics
   - `proxmox` - For Proxmox metrics
6. Generate API tokens with write access to one bucket each
6. Configure data sources to use `https://influxdb.home.jasongodson.com:443`
   - The org id can be obtained from the url `https://influxdb.home.jasongodson.com/orgs/<org_id>`
   - For Home Assistant: Use the homeassistant bucket and token
   - For Proxmox: Use the proxmox bucket and token.
       - Check `Advanced` and then uncheck `Verify Certificate`
   - No path needed