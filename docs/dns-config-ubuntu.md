### Ubuntu DNS Configuration

Configure system DNS to use your local DNS server:
```bash
# Edit /etc/systemd/resolved.conf
[Resolve]
DNS=192.168.1.253
Domains=~home.example.com
FallbackDNS=1.1.1.1
```

Restart systemd-resolved:
```bash
sudo systemctl restart systemd-resolved
```