### Compose file
```yaml
logging: 
    drive: loki
    options:
        loki-url: "http://192.168.1.4:8090/loki/api/v1/push"
        loki-retries: 2
        loki-max-backoff: 800ms
        loki-timeout: 1s
        keep-file: "true"
        mode: "non-blocking"
```

### Command line
Add the following to `docker run`

```bash
--log-driver=loki --log-opt loki-url=http://your-loki-server:3100/loki/api/v1/push --log-opt loki-retries=2 --log-opt loki-max-backoff=800ms --log-opt loki-timeout=1s --log-opt keep-file=true --log-opt mode=non-blocking
```