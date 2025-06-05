---
title: Fixing Local DNS Resolution with Cloudflare Warp and Zero Trust
description: Using Cloudflare Warp with Zero Trust is a great way to securely access your home network remotely, but local DNS resolution didn't work out of the box. Here’s how I made it work.
date: 2025-06-04
tags:
  - cloudflare
  - homelab
  - dns
layout: post.njk
---

When I travel, the main thing I need is access to my home network. With **Cloudflare Warp** and **Zero Trust** that I had previously set up, I can securely tunnel into my network, ensuring that even when I'm far from home, I can access all my devices and services.

But I had one little hiccup: **local DNS resolution** wasn't working. This means that while I can reach my home network via the tunnel, I can’t resolve local domain names (e.g., `grafana.home.jasongodson.com` or `influxdb.home.jasongodson.com`) like when I am connected to my home wireless network.

In this post, I'll show you how I fixed this issue by setting up **Local Domain Fallback** in Cloudflare Warp, allowing me to access local services like Grafana, InfluxDB, and other self-hosted apps by hostname while traveling.

## The Problem

I use **Caddy** on my home network to automatically obtain **TLS certificates** for my custom `*.home.jasongodson.com` domain. This domain exists only on my local network and gets resolved through my internal DNS server (located at `192.168.1.253`).

When I turned on Cloudflare Warp, I could no longer access any of my local services by hostname. Instead, I was forced to rely on IP addresses, which isn’t ideal for a few reasons:

1. **DNS makes life easier** — I don't want to remember IP addresses and ports.
2. **Security** — Using a domain with proper TLS certificates is safer than raw IPs.

### How Cloudflare Warp Handles DNS

By default, Cloudflare Warp routes all DNS queries through Cloudflare's 1.1.1.1 (public DNS) service. This doesn’t know anything about my internal domain, so any attempts to access `grafana.home.jasongodson.com` or `influxdb.home.jasongodson.com` would fail, even though they work perfectly fine on my local network.

### The Fix: Local Domain Fallback

**1. Configuring the DNS Fallback**
In the Cloudflare Zero Trust Dashboard under the Settings -> Warp Client. You'll see a way to edit your profiles under the "Device settings" heading.

{% image "./src/assets/images/cf-dash-warp-client.jpg", "Warp Client settings in Cloudflare Dashboard", "(min-width: 768px) 600px, 100vw" %}

Under those profile settings (`Default` in my case), **Local Domain Fallback** allows you to route DNS queries for specific hostnames to specific DNS servers, bypassing Cloudflare’s public DNS. There are some good defaults set already, however since I am using a custom domain, I had to change these. Here's how I configured it:

- **Domain**: `home.jasongodson.com`
- **DNS Servers**: `192.168.1.253` (My internal DNS server IP)

{% image "./src/assets/images/cf-dash-domain-fallback.jpg", "Domain Fallback settings in Cloudflare Dashboard", "(min-width: 768px) 600px, 100vw" %}

This tells Cloudflare Warp: “For any domain under `home.jasongodson.com`, route the DNS queries to the server at `192.168.1.253`.” You don’t need to specify a wildcard — just the base domain is enough to cover everything.

**2. Check Private Network Routing:**
Make sure your **Cloudflare Tunnel** is utilzing Split Tunnles to allow access to your home network. In the same settings screen for the Profile, you'll see **Split Tunnels**, which I have set to "Exclude IPs and domains". Ensure your home network address space is added to those exclusions (mine was by default when I set that up).

{% image "./src/assets/images/cf-dash-split-tunnels.jpg", "Split Tunnel settings in Cloudflare Dashboard", "(min-width: 768px) 600px, 100vw" %}

**3. Restart Warp Client:**
Once everything is configured, you may need to disconnect and reconnect the Warp client to ensure they apply. Try running a quick test with a DNS lookup tool like `dig` or `nslookup`:

```bash
nslookup grafana.home.jasongodson.com
```

If everything is set up correctly, your DNS query should resolve to the internal IP!

### Why This Works

The **Split Tunnel** exclusions ensure that those network addresses are available when using the Warp client. While the **Local Domain Fallback** feature essentially bypasses Cloudflare’s DNS for the specified domains, sending queries directly to the DNS server you specify. This is especially useful when you want to access internal services securely, without sacrificing the benefits of Cloudflare’s Warp tunnel.

The combination of these two settings allows me to securely access my Grafana and other self-hosted services while traveling, all by hostname, without being available on the public internet.

### Conclusion

Cloudflare Warp and Zero Trust are fantastic tools for secure, private browsing — but they’re even better when you configure them to give you access to your home network while you’re on the go. Utilizing **Local Domain Fallback**, I was able to get local DNS resolution working again, meaning I can now use hostnames like `grafana.home.jasongodson.com` while traveling, without needing to rely on static IPs.

It’s a small tweak, but it makes a big difference in ensuring that my home network remains fully accessible wherever I am.