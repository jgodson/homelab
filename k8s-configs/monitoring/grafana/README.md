### Steps
1. Create secrets (`Grafana admin credentials`, `Grafana SMTP secret`, `Grafana InfluxDB token`) in 1Password
2. Install helm chart with the deploy script `./deploy.sh`
3. Log into the admin interface at grafana.home.jasongodson.com
4. Create a new API Token in the InfluxDB admin for `Read` access to `All Buckets`.
5. Provision datasources via Helm:
    - Create a Kubernetes secret named `grafana-influxdb-token` with a key `INFLUXDB_TOKEN` set to `Token <API_TOKEN>` from above.
    - Prometheus, Loki, Tempo, and InfluxDB datasources are provisioned via `grafana-values.yaml`, so they should appear read-only in the UI.
6. You can now import previously exported dashboards (like the ones in [dashboards](./dashboards/)) if needed. However the uid of the datasource has likely changed, which means you will have to replace all the uid's for the datasource in the dashboard with the new one. This can be obtained from the url by navigating to the datasource and grabbing it from the url. 
   
   Example: `https://grafana.home.jasongodson.com/connections/datasources/edit/aegyydl2mv37kd` would be `aegyydl2mv37kd`.
    - When you see the following in the `.json` file, you would replace `fec5sxidq9534d` with `aegyydl2mv37kd` (all of them):
        ```json
        "datasource": {
            "type": "influxdb",
            "uid": "fec5sxidq9534d"
        },
        ```
    - This is easily done with the following command:
      ```bash
      sed -i '' 's/<old>/<new>/g' <file>.json
      ```
    - After doing the above, import the file using the Grafana UI and check that everything is working as expected.

7. You can add more dashboards now by id. You can find them on `https://grafana.com/grafana/dashboards/<id>`. 
   
   Recommended dashboards:
    - Node Exporter: 1860
    - Kubernetes Monitoring: 12740
    - Traefik: 5851
