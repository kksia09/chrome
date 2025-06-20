#!/bin/bash
set -e

cleanup() {
  echo "Shutting down gracefully..."
  pkill -f "Xvfb|fluxbox|x11vnc|websockify|chrome" || true
  find /tmp -maxdepth 1 -name 'chrome-profile-*' -exec rm -rf {} + 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "Cleaning Chrome profiles..."
find /tmp -maxdepth 1 -name 'chrome-profile-*' -exec rm -rf {} + 2>/dev/null

echo "Starting Xvfb..."
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +extension GLX +render -noreset \
  >/tmp/xvfb.log 2>&1 &
sleep 3
export DISPLAY=:99
xdpyinfo -display :99 >/dev/null || { echo "Xvfb failed"; cat /tmp/xvfb.log; exit 1; }

export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
eval "$(dbus-launch --sh-syntax)"

fluxbox >/tmp/fluxbox.log 2>&1 &
sleep 2

x11vnc -display :99 -forever -shared -passwd secret -bg -o /tmp/x11vnc.log
websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &
sleep 3

# Automa directory
if [ -d "/opt/automa/dist" ]; then
  AUTOMA_DIR="/opt/automa/dist"
elif [ -d "/opt/automa/build" ]; then
  AUTOMA_DIR="/opt/automa/build"
else
  echo "ERROR: Automa build not found"; ls -la /opt/automa/; exit 1
fi

chmod -R a+r "$AUTOMA_DIR"

CHROME_PROFILE_DIR="/tmp/chrome-profile-$(date +%s)"
mkdir -p "$CHROME_PROFILE_DIR"

echo "Testing extension load..."
TEST=$(google-chrome-stable \
  --headless=new --disable-gpu \
  --disable-extensions-except="$AUTOMA_DIR" \
  --load-extension="$AUTOMA_DIR" \
  --print-to-pdf=/dev/null 2>&1 || true)

if echo "$TEST" | grep -q "Extension"; then
  echo "✅ Test load OK in headless=new"
else
  echo "⚠️ Warning: Extension may not load in headless mode. GUI mode will be used."
fi

echo "Starting Chrome (GUI mode) with extension..."
google-chrome-stable \
  --disable-extensions-except="$AUTOMA_DIR" \
  --load-extension="$AUTOMA_DIR" \
  --no-sandbox --disable-setuid-sandbox \
  --disable-gpu --disable-dev-shm-usage \
  --user-data-dir="$CHROME_PROFILE_DIR" \
  --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 \
  --disable-features=UseOzonePlatform,VizDisplayCompositor \
  --window-size=1920,1080 --start-maximized \
  >/tmp/chrome.log 2>&1 &

sleep 8
if ! pgrep -f "chrome" >/dev/null; then
  echo "Chrome failed to start; last logs:"; tail -20 /tmp/chrome.log
  exit 1
fi

xterm -geometry 80x24+50+50 -title "Debug Terminal" &

cat <<EOF
==============================================
✅ Environment Ready!
GUI:        http://localhost:6080/vnc.html (password: secret)
DevTools:   http://localhost:9222
Ext path:   $AUTOMA_DIR
Profile:    $CHROME_PROFILE_DIR
Logs: Chrome: /tmp/chrome.log
==============================================
EOF

[ "$1" = "--logs" ] && tail -f /tmp/chrome.log /tmp/x11vnc.log
tail -f /dev/null
