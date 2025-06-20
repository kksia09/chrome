#!/bin/bash
set -e

# Cleanup function for graceful shutdown
cleanup() {
    echo "Shutting down gracefully..."
    pkill -f "Xvfb|fluxbox|x11vnc|websockify|chrome" || true
    # Clean up Chrome profiles
    find /tmp -maxdepth 1 -name 'chrome-profile-*' -exec rm -rf {} + 2>/dev/null
    exit 0
}

# Trap container exit signals
trap cleanup SIGINT SIGTERM

echo "Starting Automa GUI environment..."

# Cleanup any residual Chrome profile locks
echo "Cleaning up old Chrome profiles..."
find /tmp -maxdepth 1 -name 'chrome-profile-*' -exec rm -rf {} + 2>/dev/null

# Cleanup any existing X server locks
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

# Kill existing processes that might conflict
pkill -9 Xvfb || true
pkill -9 fluxbox || true
pkill -9 x11vnc || true
pkill -9 websockify || true
pkill -9 chrome || true

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
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS
export DBUS_SESSION_BUS_PID

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

# Create UNIQUE Chrome user data directory
CHROME_PROFILE_DIR="/tmp/chrome-profile-$(date +%s)"
mkdir -p "$CHROME_PROFILE_DIR"
echo "Using Chrome profile directory: $CHROME_PROFILE_DIR"

# Start Chrome with Automa extension
echo "Starting Chrome with Automa extension..."
google-chrome-stable \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --disable-software-rasterizer \
  --disable-features=UseOzonePlatform,VizDisplayCompositor \
  --window-size=1920,1080 \
  --start-maximized \
  --window-position=0,0 \
  --load-extension=$AUTOMA_DIR \
  --enable-extensions \
  --disable-web-security \
  --user-data-dir="$CHROME_PROFILE_DIR" \
  --no-first-run \
  --no-default-browser-check \
  --enable-logging=stderr \
  --v=1 \
  --remote-debugging-port=9222 \
  --remote-debugging-address=0.0.0.0 \
  >/tmp/chrome.log 2>&1 &

# Wait for Chrome to start
sleep 8  # Increased sleep time for Chrome initialization

# Check if Chrome started successfully
if pgrep -f "google-chrome" > /dev/null; then
    echo "Chrome started successfully"
else
    echo "ERROR: Chrome failed to start. Check logs:"
    tail -20 /tmp/chrome.log
    
    # Attempt to capture Chrome exit code
    CHROME_PID=$!
    if wait $CHROME_PID; then
        echo "Chrome exited with status $?"
    else
        echo "Chrome exited with status $?"
    fi
    
    exit 1
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
echo "📋 Chrome profile: $CHROME_PROFILE_DIR"
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