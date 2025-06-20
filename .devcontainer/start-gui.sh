#!/bin/bash
set -e

echo "Starting Automa GUI environment..."

# Cleanup any existing X server locks
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# Start virtual display
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +extension GLX \
      +render -noreset >/tmp/xvfb.log 2>&1 &

# Wait for Xvfb to start
sleep 3
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  echo "ERROR: Xvfb failed to start!"
  cat /tmp/xvfb.log
  exit 1
fi

export DISPLAY=:99
echo "Xvfb started successfully on display :99"

# Start DBUS
echo "Starting DBUS..."
dbus-launch --sh-syntax > /tmp/dbus-env
source /tmp/dbus-env

# Configure Fluxbox
mkdir -p /root/.fluxbox
cat > /root/.fluxbox/init << EOF
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: true
session.screen0.workspaces: 1
session.screen0.workspaceNames: Main
EOF

# Start window manager
echo "Starting Fluxbox window manager..."
fluxbox >/tmp/fluxbox.log 2>&1 &
sleep 2

# Start VNC server
echo "Starting VNC server..."
x11vnc -display :99 -forever -shared -passwd secret -bg \
       -o /tmp/x11vnc.log

# Start noVNC web interface
echo "Starting noVNC web interface..."
websockify --web /usr/share/novnc 6080 localhost:5900 \
           >/tmp/websockify.log 2>&1 &

# Wait for noVNC to start
sleep 3

# Check for Automa build directory (could be 'dist' or 'build')
AUTOMA_DIR=""
if [ -d "/opt/automa/dist" ]; then
    AUTOMA_DIR="/opt/automa/dist"
elif [ -d "/opt/automa/build" ]; then
    AUTOMA_DIR="/opt/automa/build"
else
    echo "ERROR: Automa build directory not found"
    echo "Available directories in /opt/automa:"
    ls -la /opt/automa/
    exit 1
fi

echo "Using Automa extension from: $AUTOMA_DIR"

# Start Chrome with Automa extension
echo "Starting Chrome with Automa extension..."
google-chrome-stable \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --disable-software-rasterizer \
  --window-size=1920,1080 \
  --start-maximized \
  --window-position=0,0 \
  --load-extension=$AUTOMA_DIR \
  --enable-extensions \
  --disable-web-security \
  --disable-features=VizDisplayCompositor \
  --enable-logging=stderr \
  --v=1 \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  >/tmp/chrome.log 2>&1 &

# Wait for Chrome to start
sleep 5

# Check if Chrome started successfully
if pgrep -f "google-chrome" > /dev/null; then
    echo "Chrome started successfully"
else
    echo "ERROR: Chrome failed to start. Check logs:"
    tail -20 /tmp/chrome.log
fi

# Start xterm for debugging (optional)
xterm -geometry 80x24+50+50 -title "Debug Terminal" &

# Show connection info
echo "=============================================="
echo "✅ Automa GUI Environment Ready!"
echo "=============================================="
echo "🌐 Access GUI at: http://localhost:6080/vnc.html"
echo "🔑 VNC Password: secret"
echo "🔧 Chrome DevTools: http://localhost:9222"
echo "=============================================="
echo "📋 Extension loaded from: $AUTOMA_DIR"
echo "📝 Log files:"
echo "   - Chrome: /tmp/chrome.log"
echo "   - Xvfb: /tmp/xvfb.log"
echo "   - Fluxbox: /tmp/fluxbox.log"
echo "   - VNC: /tmp/x11vnc.log"
echo "   - noVNC: /tmp/websockify.log"
echo "=============================================="

# Function to show logs
show_logs() {
    echo "=== Chrome Logs ==="
    tail -f /tmp/chrome.log &
    CHROME_PID=$!
    
    echo "=== VNC Logs ==="
    tail -f /tmp/x11vnc.log &
    VNC_PID=$!
    
    # Clean up on exit
    trap "kill $CHROME_PID $VNC_PID 2>/dev/null" EXIT
}

# Keep container running and optionally show logs
if [ "$1" = "--logs" ]; then
    show_logs
fi

# Keep container running
tail -f /dev/null