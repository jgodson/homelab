### Compose file
```yaml
logging: 
    driver: loki
    options:
      loki-url: "https://loki.home.jasongodson.com/loki/api/v1/push"
      loki-retries: 2
      loki-max-backoff: 800ms
      loki-timeout: 1s
      keep-file: "true"
      mode: "non-blocking"
      max-size: "10m"
      max-file: "3"
```

### Command line
Add the following to `docker run`

```bash
--log-driver=loki --log-opt loki-url=https://loki.home.jasongodson.com/loki/api/v1/push --log-opt loki-retries=2 --log-opt loki-max-backoff=800ms --log-opt loki-timeout=1s --log-opt keep-file=true --log-opt mode=non-blocking --log-opt max-size=10m --log-opt max-file=3
```