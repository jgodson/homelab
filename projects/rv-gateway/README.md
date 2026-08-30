# RV network gateway

The RV Raspberry Pi 3 bridges devices that cannot run Tailscale themselves. It
proxies the remote Tapo C120 to Frigate and presents home Jellyfin to Roku
clients on the RV LAN. It deliberately does not advertise the RV subnet because
the home and RV LANs use overlapping private address ranges.

Keep the following deployment-specific values outside Git:

- RV Wi-Fi SSID and password
- Pi and camera LAN addresses
- camera MAC address
- Pi, Frigate, and media server Tailscale addresses or MagicDNS names
- Tapo Camera Account credentials

## Restore

Image a Raspberry Pi 3 with Raspberry Pi OS Lite 32-bit and configure:

- hostname `rv-pi`
- user `manager`
- the private RV Wi-Fi credentials
- SSH public-key authentication

Copy the setup script to the Pi, then provide the camera address at runtime:

```bash
sudo ./setup-tailscale-camera-proxy.sh <RV_CAMERA_IP>
```

Alternatively, set `RV_CAMERA_IP` in a private shell environment before running
the script. The script installs Tailscale from its official Raspbian repository,
enables automatic startup, grants the `manager` user permission to manage
Tailscale, and creates a persistent tailnet-only TCP proxy on port `8554`.

Follow the displayed Tailscale authorization link if the Pi is not already in
the tailnet. For this unattended gateway, open the Tailscale admin console's
Machines page, select `rv-pi`, and disable key expiry.

The Tapo app must have a Camera Account configured for this specific camera.
The credentials are used by Frigate and must not be stored on this gateway or
committed to Git.

## Verification

On the Pi:

```bash
tailscale status
tailscale serve status
nc -vz <RV_CAMERA_IP> 554
```

From a different tailnet device, verify the private proxy:

```bash
nc -vz <RV_PI_TAILSCALE_IP> 8554
```

Frigate uses RTSP over TCP through the proxy:

```text
rtsp://CAMERA_USER:CAMERA_PASSWORD@<RV_PI_TAILSCALE_IP>:8554/stream1
rtsp://CAMERA_USER:CAMERA_PASSWORD@<RV_PI_TAILSCALE_IP>:8554/stream2
```

## Home-side connection

The Frigate host and `rv-pi` must join the same tailnet. Do not add an RV subnet
route: the narrow RTSP proxy avoids conflicts between overlapping home and RV
LAN address ranges.

Store the proxy endpoint as `FRIGATE_TAPO_RV_HOST` in the untracked
`frigate.env` file. Store the local camera endpoint as
`FRIGATE_TAPO_LOCAL_HOST`. After rebuilding either node, confirm connectivity
from the Frigate host:

```bash
tailscale status
nc -vz <RV_PI_TAILSCALE_IP> 8554
```

## Jellyfin for Roku

Roku clients cannot join the tailnet directly. The Pi therefore listens on its
RV LAN port `8096` and forwards raw TCP traffic to the existing Jellyfin server
over Tailscale. The Pi does not terminate TLS, inspect media, or transcode.

First join the Jellyfin host to the same tailnet. Then copy this directory to the
Pi and provide the Jellyfin host's private Tailscale address or MagicDNS name at
runtime:

```bash
sudo ./setup-jellyfin-proxy.sh <JELLYFIN_TAILSCALE_HOST>:8096
```

The installer writes that private target to the root-only
`/etc/rv-jellyfin-proxy.env`, installs the socket-activated proxy, and enables it
at boot. Test it on the Pi:

```bash
curl http://127.0.0.1:8096/health
systemctl status rv-jellyfin-proxy.socket --no-pager
```

In the Jellyfin Roku app, manually add:

```text
http://<RV_PI_LAN_IP>:8096
```

Jellyfin UDP discovery on port `7359` is not forwarded, so automatic discovery
is not expected. Keep the Pi's RV LAN address stable; if it changes, update the
manual server address in the Roku app. Transcoding remains the responsibility
of the home Jellyfin host.
