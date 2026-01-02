# Scripts

Short notes on the scripts in this folder and how to use them.

## create-github-issues.py

Creates GitHub issues from a JSON or YAML file.

Usage:
```bash
./scripts/create-github-issues.py --token YOUR_TOKEN --file scripts/issues/issues.yaml --repo owner/name
```

Input format (YAML or JSON):
```yaml
- title: "Issue title"
  description: "Optional description"
  labels: ["bug", "ui"]
```
```json
[
  {
    "title": "Issue title",
    "description": "Optional description",
    "labels": ["bug", "ui"]
  }
]
```

Notes:
- Issue files can live under `scripts/issues` (ignored by git).
- YAML parsing requires PyYAML. On macOS: `python3 -m pip install --user pyyaml`.

## remote-build.sh

Syncs a local directory to a remote host, builds a Docker image there, and pushes it to the configured registry. Since building images for Linux is on Mac, I use this to build it on a Linux VM and upload it to the registry.

The final segment of the path is used as the remote directory and the image tag. For example `~/github/myapp` is uploaded to `<remote_host>:~/myapp` and tagged `<registry>/myapp:latest`

Usage:
```bash
./scripts/remote-build.sh path/to/local/dir
```

Notes:
- Must run `docker login` on the remote host before running.
- The script has two variables `REGISTRY_PREFIX` and `REMOTE_HOST` that would need to be tweaked before using it for yourself.
