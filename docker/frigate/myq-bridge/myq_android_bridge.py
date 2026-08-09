#!/usr/bin/env python3
"""Keep the MyQ Android SDK feeding two private H.264 named pipes."""

from __future__ import annotations

import json
import logging
import os
import signal
import socket
import stat
import subprocess
import sys
import time
from pathlib import Path

import frida


CONTAINER = os.environ.get("MYQ_ANDROID_CONTAINER", "myq-android")
PACKAGE = "com.chamberlain.android.liftmaster.myq"
ACTIVITY = f"{PACKAGE}/com.chamberlain.myq.main.HomeTabsActivity"
FRIDA_SERVER = "/data/local/tmp/frida-server-myq16"
ANDROID_FILES = Path(
    os.environ.get(
        "MYQ_ANDROID_FILES",
        "/home/manager/myq-android/android-data/data/"
        "com.chamberlain.android.liftmaster.myq/files",
    )
)
OPENER_DEVICE_ID = os.environ.get("MYQ_OPENER_DEVICE_ID", "").strip()
KEYPAD_DEVICE_ID = os.environ.get("MYQ_KEYPAD_DEVICE_ID", "").strip()
if not OPENER_DEVICE_ID or not KEYPAD_DEVICE_ID:
    raise RuntimeError(
        "MYQ_OPENER_DEVICE_ID and MYQ_KEYPAD_DEVICE_ID must be configured"
    )
CAMERAS = {
    OPENER_DEVICE_ID: "myq-opener.h264.pipe",
    KEYPAD_DEVICE_ID: "myq-keypad.h264.pipe",
}
APP_UID = int(os.environ.get("MYQ_ANDROID_APP_UID", "10116"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
LOG = logging.getLogger("myq-android-bridge")
STOP = False


def docker(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["docker", *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
    )
    return result.stdout.strip()


def ensure_fifos() -> None:
    ANDROID_FILES.mkdir(parents=True, exist_ok=True)
    for filename in CAMERAS.values():
        target = ANDROID_FILES / filename
        try:
            mode = target.stat().st_mode
            if not stat.S_ISFIFO(mode):
                raise RuntimeError(f"Refusing to replace non-FIFO path: {target}")
        except FileNotFoundError:
            os.mkfifo(target, 0o600)
        os.chown(target, APP_UID, APP_UID)
        os.chmod(target, 0o600)


def container_ip() -> str:
    raw = docker("inspect", CONTAINER)
    info = json.loads(raw)[0]
    networks = info["NetworkSettings"]["Networks"]
    addresses = [item.get("IPAddress") for item in networks.values() if item.get("IPAddress")]
    if not addresses:
        raise RuntimeError("Android container has no IPv4 address")
    return addresses[0]


def port_open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=1):
            return True
    except OSError:
        return False


def ensure_android_and_frida() -> str:
    docker("start", CONTAINER, check=False)
    for _ in range(60):
        booted = docker("exec", CONTAINER, "getprop", "sys.boot_completed", check=False)
        package = docker("exec", CONTAINER, "pm", "path", PACKAGE, check=False)
        if booted == "1" and package.startswith("package:"):
            break
        time.sleep(1)
    else:
        raise RuntimeError("Android did not become ready")
    address = container_ip()
    if not port_open(address, 27042):
        docker(
            "exec",
            "-d",
            CONTAINER,
            FRIDA_SERVER,
            "-P",
            "--policy-softener=internal",
            "-l",
            "0.0.0.0:27042",
        )
        for _ in range(20):
            if port_open(address, 27042):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Frida server did not start")
    docker("exec", CONTAINER, "am", "start", "-n", ACTIVITY, check=False)
    return address


def agent_source(suffix: str) -> str:
    camera_entries = ",".join(
        f"'{device_id}':'{filename}'" for device_id, filename in CAMERAS.items()
    )
    return rf"""
var cameraFiles={{{camera_entries}}};
var managers=[];
var outputs={{}};
var stats={{}};
var started=false;
var stopped=false;

function snapshot() {{
  var out={{started:started,stopped:stopped,sessionLength:0,cameras:{{}}}};
  try {{ out.sessionLength=String(Java.use('com.seedonk.im.ServerManager').getSessionId()).length; }} catch(e) {{}}
  Object.keys(stats).forEach(function(id) {{ out.cameras[id]=Object.assign({{}},stats[id]); }});
  return out;
}}

function dismissCompatibilityDialog() {{
  return new Promise(function(resolve) {{
    Java.perform(function() {{
      var dismissed=false;
      Java.choose('android.app.AlertDialog', {{
        onMatch:function(dialog) {{
          try {{
            var messageView=dialog.findViewById(16908299);
            var message=messageView ? String(messageView.getText()) : '';
            if(message.indexOf('Google Play services') === -1)return;
            var button=dialog.getButton(-1);
            if(!button)return;
            dismissed=true;
            Java.scheduleOnMainThread(function() {{try{{button.performClick();}}catch(e){{}}}});
          }} catch(e) {{}}
        }},
        onComplete:function() {{resolve(dismissed);}}
      }});
    }});
  }});
}}

function closeOutput(id) {{
  try {{ if(outputs[id])outputs[id].close(); }} catch(e) {{}}
  outputs[id]=null;
}}

function outputFor(id) {{
  if(outputs[id])return outputs[id];
  var AT=Java.use('android.app.ActivityThread');
  var FOS=Java.use('java.io.FileOutputStream');
  var path=String(AT.currentApplication().getFilesDir().getAbsolutePath())+'/'+cameraFiles[id];
  outputs[id]=FOS.$new(path,false);
  return outputs[id];
}}

function startCamera(id,index,VI,CI,SDK) {{
  stats[id]={{connected:false,frames:0,bytes:0,width:0,height:0,keyframes:0,lastFrameAt:0,error:''}};
  var Listener=Java.registerClass({{
    name:'com.openai.MyQVideoListener_{suffix}_'+index,
    implements:[VI],
    methods:{{
      onAutoAdjustActualReceivedFpsCalculated:function(v){{}},
      onAutoAdjustFpsChanged:function(v){{}},
      onAutoAdjustQualityChanged:function(v){{}},
      onDataReceiveTimedOut:function(v){{}},
      onDecodedVideoDataReceived:function(v){{}},
      onDeviceFpsChanged:function(v){{}},
      onEncodedVideoDataReceived:function(frame){{
        var s=stats[id];
        try {{
          var data=frame.getVideoFrameData();
          outputFor(id).write(data);
          s.frames++;s.bytes+=frame.getDataSize();s.width=frame.getWidth();s.height=frame.getHeight();
          if(frame.isKeyFrame())s.keyframes++;
          s.lastFrameAt=Date.now();
        }} catch(e) {{ s.error=String(e);closeOutput(id); }}
      }},
      onFirstVideoDataReceived:function(){{}},
      onVideoConnectFailed:function(e){{stats[id].error=String(e);}},
      onVideoConnected:function(){{stats[id].connected=true;}},
      onVideoDisconnected:function(e){{stats[id].connected=false;}},
      onVideoSizeUpdated:function(w,h){{stats[id].width=w;stats[id].height=h;}}
    }}
  }});
  var Completion=Java.registerClass({{
    name:'com.openai.MyQConnectCompletion_{suffix}_'+index,
    implements:[CI],
    methods:{{completed:function(e){{if(e!==null)stats[id].error=String(e);}}}}
  }});
  var manager=SDK.getInstance().videoCallManagerWithDeviceId(id,Listener.$new(),null);
  if(manager===null)throw new Error('No video manager for '+id);
  managers.push(manager);
  manager.connect(Completion.$new());
}}

rpc.exports={{
  dismisscompatibility:function(){{return dismissCompatibilityDialog();}},
  sessionlength:function(){{return new Promise(function(resolve){{Java.perform(function(){{try{{resolve(String(Java.use('com.seedonk.im.ServerManager').getSessionId()).length);}}catch(e){{resolve(0);}}}});}});}},
  start:function(){{return new Promise(function(resolve){{Java.perform(function(){{
    if(started)return resolve(snapshot());
    try {{
      var VI=Java.use('com.seedonk.mobilesdk.VideoConnectionManager$VideoConnectionListener');
      var CI=Java.use('com.seedonk.mobilesdk.VideoCallManager$ConnectCompletion');
      var SDK=Java.use('com.seedonk.mobilesdk.SdkConfig');
      Object.keys(cameraFiles).forEach(function(id,index){{startCamera(id,index,VI,CI,SDK);}});
      started=true;
      resolve(snapshot());
    }} catch(e) {{resolve({{started:false,error:String(e)}});}}
  }});}});}},
  stats:function(){{return new Promise(function(resolve){{Java.perform(function(){{resolve(snapshot());}});}});}},
  stop:function(){{return new Promise(function(resolve){{Java.perform(function(){{
    stopped=true;
    managers.forEach(function(m){{try{{m.disconnect(null);}}catch(e){{}}}});
    Object.keys(outputs).forEach(closeOutput);
    resolve(true);
  }});}});}}
}};
"""


def wait_for_process(device: frida.core.Device) -> int:
    for _ in range(60):
        if STOP:
            raise InterruptedError
        try:
            return device.get_process("myQ-I").pid
        except frida.ProcessNotFoundError:
            time.sleep(1)
    raise RuntimeError("MyQ Android process did not start")


def run_agent(address: str) -> None:
    device = frida.get_device_manager().add_remote_device(f"{address}:27042")
    pid = wait_for_process(device)
    session = device.attach(pid)
    detached = False

    def on_detached(*_args) -> None:
        nonlocal detached
        detached = True

    session.on("detached", on_detached)
    suffix = f"{pid}_{int(time.time())}".replace("-", "_")
    script = session.create_script(agent_source(suffix))
    try:
        script.load()

        for _ in range(60):
            if STOP:
                raise InterruptedError
            if detached:
                raise RuntimeError("Frida session detached")
            try:
                script.exports_sync.dismisscompatibility()
            except Exception:
                pass
            if script.exports_sync.sessionlength() > 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError("MyQ video session did not become ready")

        result = script.exports_sync.start()
        if not result.get("started"):
            raise RuntimeError(
                f"Android video start failed: {result.get('error', 'unknown error')}"
            )
        LOG.info("Both Android camera sessions requested")

        last_counts: dict[str, int] = {}
        stalled_checks = 0
        while not STOP and not detached:
            time.sleep(15)
            current = script.exports_sync.stats()
            cameras = current.get("cameras", {})
            summary = []
            advancing = True
            for device_id in CAMERAS:
                details = cameras.get(device_id, {})
                count = int(details.get("frames", 0))
                advancing = advancing and count > last_counts.get(device_id, -1)
                last_counts[device_id] = count
                summary.append(
                    f"{device_id}:{details.get('width', 0)}x{details.get('height', 0)} "
                    f"frames={count}"
                )
            LOG.info("; ".join(summary))
            stalled_checks = 0 if advancing else stalled_checks + 1
            if stalled_checks >= 4:
                raise RuntimeError("One or more camera streams stopped advancing")

        if detached and not STOP:
            raise RuntimeError("Frida session detached")
    finally:
        try:
            script.exports_sync.stop()
        except Exception:
            pass
        try:
            session.detach()
        except Exception:
            pass


def handle_signal(_signum, _frame) -> None:
    global STOP
    STOP = True


def restart_android_app() -> None:
    LOG.warning("Restarting the MyQ app to renew its video session")
    docker("exec", CONTAINER, "am", "force-stop", PACKAGE, check=False)
    time.sleep(2)
    docker("exec", CONTAINER, "am", "start", "-W", "-n", ACTIVITY, check=False)
    time.sleep(5)


def main() -> int:
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    ensure_fifos()
    while not STOP:
        try:
            address = ensure_android_and_frida()
            run_agent(address)
        except InterruptedError:
            break
        except Exception as error:
            LOG.error("Bridge cycle failed: %s", error)
            if not STOP:
                error_text = str(error).lower()
                restart_markers = (
                    "video session did not become ready",
                    "camera streams stopped advancing",
                    "android video start failed",
                    "script has been destroyed",
                    "frida session detached",
                )
                if any(marker in error_text for marker in restart_markers):
                    try:
                        restart_android_app()
                    except Exception as restart_error:
                        LOG.error("MyQ app restart failed: %s", restart_error)
                time.sleep(5)
    return 0


if __name__ == "__main__":
    sys.exit(main())
