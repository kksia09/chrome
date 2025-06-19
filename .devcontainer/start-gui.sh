#!/bin/bash
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +extension GLX \
      +render -noreset >/tmp/xvfb.log 2>&1 &
sleep 3
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  echo "Xvfb failed to start!"
  cat /tmp/xvfb.log
  exit 1
fi

export DISPLAY=:99
dbus-launch --sh-syntax > /tmp/dbus-env
source /tmp/dbus-env

fluxbox >/tmp/fluxbox.log 2>&1 &
x11vnc -display :99 -forever -shared -passwd secret -bg >/tmp/x11vnc.log 2>&1
websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &

google-chrome \
  --no-sandbox \
  --disable-gpu \
  --window-size=1920,1080 \
  --start-maximized \
  --load-extension=/opt/automa/build \
  --enable-logging=stderr \
  --v=1 >/tmp/chrome.log 2>&1 &

# Tail Chrome logs directly to container stdout (replaces xterm)
tail -f /tmp/chrome.log &

# Optional GUI test apps (keep if needed)
xeyes & xclock &

echo "=============================================="
echo "Access Chrome GUI at: http://localhost:6080/vnc.html"
echo "Password: secret"
echo "=============================================="
echo "Logs: /tmp/chrome.log, xvfb.log, fluxbox.log, x11vnc.log"
echo "=============================================="

# Keep container running
tail -f /dev/null