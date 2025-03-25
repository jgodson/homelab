### Compose file
```yaml
logging: 
    driver: loki
    options:
      loki-url: "http://loki.home.jasongodson.com/loki/api/v1/push"
      loki-retries: 2
      loki-max-backoff: 800ms
      loki-timeout: 1s
      keep-file: "true"
      mode: "non-blocking"
```

### Command line
Add the following to `docker run`

```bash
--log-driver=loki --log-opt loki-url=http://loki.home.jasongodson.com/loki/api/v1/push --log-opt loki-retries=2 --log-opt loki-max-backoff=800ms --log-opt loki-timeout=1s --log-opt keep-file=true --log-opt mode=non-blocking
```