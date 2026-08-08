# Frigate NVR

This directory backs up the working Frigate configuration for the host at `192.168.1.3`, including the host-resident MyQ camera bridge.

## Current cameras and detection

- `myq_opener`: 1280x720 H.264, detection at 10 FPS
- `myq_keypad`: 1152x864 H.264, detection at 10 FPS
- `person` creates an alert review item
- `dog` and `cat` create detection review items
- Alert and detection recordings are retained for 10 days
- Continuous and motion recordings are retained for 1 day
- The two broken Wyze RTSP cameras remain as sanitized comments in `config/config.yml`

Frigate uses eleven OpenVINO CPU detector processes and the bundled SSD MobileNet v2 model. Multiple workers consume a shared detection queue across both cameras.

## Layout

```text
config/config.yml                 Frigate and go2rtc configuration
docker-compose.yml                Frigate plus the private H.264 pipe service
myq-bridge/                       ReDroid, systemd, and H.264 bridge source
```

The MyQ bridge runs the official Android app in ReDroid. A host systemd service attaches to the app's installed video SDK, writes the two encoded H.264 streams to private FIFOs, and `myq-video-pipe` exposes them only on Frigate's Docker network. The bridge automatically relaunches the app and dismisses its Google Play Services compatibility dialog when the video session expires.

MyQ Internet access is still required. This repository does not contain an authenticated Android data directory, the MyQ APK, or the Frida server binary.

## Restore

The commands below assume this directory is the working directory on the new Frigate host and the Linux user is `manager`.

### 1. Load Android Binder support

```bash
sudo install -o root -g root -m 0644 myq-bridge/myq-android.modules-load.conf /etc/modules-load.d/myq-android.conf
sudo install -o root -g root -m 0644 myq-bridge/myq-android.modprobe.conf /etc/modprobe.d/myq-android.conf
sudo modprobe binder_linux
```

### 2. Start ReDroid and sign in to MyQ

```bash
mkdir -p /home/manager/myq-android
cp myq-bridge/docker-compose.android.yml /home/manager/myq-android/docker-compose.yml
cd /home/manager/myq-android
docker compose up -d
```

Install the Chamberlain-signed MyQ Android APK into `myq-android`, then use the loopback-only ADB port through an SSH tunnel to open the Android UI and sign in. The tested app build was `5.243.1.73243` on Android 11 x86_64.

### 3. Install the host bridge

Copy `myq-bridge` to `/home/manager/myq-frigate-bridge`. Create the Python environment and install the tested Frida client:

```bash
python3 -m venv /home/manager/myq-frida-venv
/home/manager/myq-frida-venv/bin/pip install 'frida==16.7.19'
```

Place the matching Frida server x86_64 binary in the Android container as `/data/local/tmp/frida-server-myq16` and make it executable.

Install the device configuration and systemd unit:

```bash
sudo install -o root -g root -m 0600 myq-bridge/myq-frigate-bridge.env.example /etc/myq-frigate-bridge.env
sudo install -o root -g root -m 0644 myq-bridge/myq-android-bridge.service /etc/systemd/system/myq-android-bridge.service
sudo systemctl daemon-reload
sudo systemctl enable --now myq-android-bridge.service
```

The numeric device IDs in the example environment file are identifiers, not account credentials. Update them if the MyQ account or devices change.

### 4. Start Frigate

Return to this directory and run:

```bash
mkdir -p storage
docker compose up -d --build
```

Open Frigate on port `8971`, create the initial account if needed, and configure notification email through Frigate without committing it to Git.

## Health checks

```bash
sudo systemctl status myq-android-bridge.service
sudo journalctl -u myq-android-bridge.service -n 30 --no-pager
docker exec myq-video-pipe wget -qO- http://127.0.0.1:8091/health
docker exec frigate wget -qO- http://127.0.0.1:1984/api/streams
```

The bridge health check requires recent bytes from both cameras, so a stalled feed no longer appears healthy.

## References

- [Frigate configuration](https://docs.frigate.video/configuration/)
- [Frigate review items](https://docs.frigate.video/configuration/review/)
- [Frigate object detectors](https://docs.frigate.video/configuration/object_detectors/)
