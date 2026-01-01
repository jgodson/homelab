---
title: How I Set Up Grafana Email Alerts with Gmail, Cloudflare, and Kubernetes
description: A straightforward, secure way to route Grafana alerts through Gmail using Cloudflare Email Routing and Kubernetes secrets.
date: 2025-05-19
tags:
  - monitoring
  - kubernetes
  - cloudflare
  - homelab
  - infrastucture
layout: post.njk
---

I've been using Grafana in my homelab for a while to monitor things — dashboards for metrics, logs for troubleshooting. However, I had not yet set up any alerts. Mainly because I didn't have a good place to send them. I wanted to make sure alerts wouldn't go unnoticed and Email was the obvious choice — simple, reliable, and accessible from anywhere. But as usual in a homelab setup, the question became: **how can I self-host**?

## The Self-Hosted Mail Server Rabbit Hole

Initially, I explored running my own mail server. There are some great all-in-one solutions like [Mailu](https://mailu.io/) and [Mailcow](https://mailcow.email/), and they can run in Docker or, in some cases, Kubernetes. But once I got into the details — besides that it wouldn't work behind a **Cloudflare tunnel**, there was reverse DNS, IP reputation, spam filtering, greylisting, and potential that my internet provider blocks the outgoing SMTP port to deal with — it was clear that for **just sending and receiving a few alerts**, it wasn’t worth the operational overhead. So I continued looking for something better.

## Discovering Cloudflare Email Routing

Cloudflare’s [Email Routing](https://developers.cloudflare.com/email-routing/) feature was a game changer. It lets you forward any email sent to your domain to a personal inbox like Gmail or Outlook — **no mail server required**.

Setup was super easy. I added a forwarding address to my Gmail, and Cloudflare showed which `MX` and `TXT` records I needed to add to my DNS configuration. Since my domain is already managed through Cloudflare, it was a one-click apply — and emails started arriving almost instantly. I didn’t need to expose ports, run postfix, or configure spam filters. Inbound mail? Solved.

## Outbound: Sending with Gmail’s SMTP Relay

With inbound mail handled, next up was sending alerts from Grafana via email.

Rather than setting up a dedicated mail-sending service, I configured Grafana to send via **Gmail's SMTP server**. All it required was:
- An app-specific password (since I use 2FA)
- SMTP config pointed at `smtp.gmail.com:587`

To keep everything secure and Git-friendly, I stored credentials in Kubernetes Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-smtp
  namespace: monitoring
type: Opaque
stringData:
  user: mygmail@gmail.com
  password: app-specific-password
```

Then I referenced them in `values.yaml` when deploying Grafana via Helm:

```yaml
grafana:
  grafana.ini:
    smtp:
      enabled: true
      host: smtp.gmail.com:587
      from_name: Grafana Alerts

smtp:
  existingSecret: grafana-smtp
  userKey: user
  passwordKey: password
```

I also templated the `from_address` using a second secret, ensuring nothing sensitive ended up in version control. Then to make sure I didn't accidently forget to add it when updating the deployment, I added a short bash script to deploy the chart with.

```bash
#!/bin/bash

NAMESPACE="monitoring"
RELEASE_NAME="grafana"
CHART_NAME="grafana/grafana"
EMAIL_SECRET_NAME="grafana-email"
EMAIL_KEY="from_address"

# Pull from_address from the Kubernetes Secret
FROM_EMAIL=$(kubectl get secret "$EMAIL_SECRET_NAME" \
  -n "$NAMESPACE" \
  -o "jsonpath={.data.${EMAIL_KEY}}" | base64 --decode)

if [ -z "$FROM_EMAIL" ]; then
  echo "❌ Could not retrieve from_address from secret '$EMAIL_SECRET_NAME'"
  exit 1
fi

echo "📧 Using from_address: $FROM_EMAIL"

helm upgrade --install "$RELEASE_NAME" "$CHART_NAME" \
  -n "$NAMESPACE" \
  -f values.yaml \
  --set "grafana.grafana.ini.smtp.from_address=${FROM_EMAIL}"
```

After setting that up, I sent a test alert in Grafana and... nothing. The odd thing was I did see that _something_ happened in Cloudflare's Email Routing dashboard. So what was going on?

After checking my Sent messages in Gmail, I did see it there. However, it seemed like it just stayed there, rather than going to my Inbox. That is definitely something I needed to happen for this to be useful.

After some Googling, I realized I needed to add the custom address to Gmail under **"Send mail as"** and verify it. After recieving the verification email and clicking the verification link, I tested again and it showed up in my Inbox!

{% image "./src/assets/images/gmail-inbox.jpg", "Alert in my Gmail inbox", "(min-width: 768px) 600px, 100vw" %}

In addition, I made sure to set up a filter to avoid marking it as spam and:
  - Categorize it as "Primary"
  - Apply an "Alert" label
  - Mark it as important

## Conclusion

I started out thinking I’d need to run my own mail server, but Cloudflare and Gmail gave me exactly what I needed with a fraction of the hassle. With this setup:

- ✅ I can receive email at a custom domain without hosting mail
- ✅ Grafana alerts send reliably via Gmail SMTP
- ✅ All secrets are stored securely in Kubernetes
- ✅ Gmail filters keep alerts visible and organized

For a homelab setup, this strikes the perfect balance of control, simplicity, and reliability. Now I just need to configure more alerts to take full advantage of it.

{% image "./src/assets/images/grafana-alerts.jpg", "Alerts configured in Grafana", "(min-width: 768px) 600px, 100vw" %}