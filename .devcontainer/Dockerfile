FROM node:20-bullseye

# Install Chrome dependencies and GUI tools
RUN apt-get update && apt-get install -y \
    ca-certificates \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    wget \
    xdg-utils \
    xvfb \
    fluxbox \
    x11vnc \
    novnc \
    websockify \
    dbus-x11 \
    x11-apps \
    net-tools

# Install Chrome
RUN wget -O /tmp/chrome.deb \
    https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb

# Create enhanced GUI startup script
RUN echo '#!/bin/bash\n\
# Clean up previous X server locks\n\
rm -f /tmp/.X99-lock\n\
rm -f /tmp/.X11-unix/X99\n\
\n\
# Start Xvfb\n\
Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR +extension GLX +render -noreset >/tmp/xvfb.log 2>&1 &\n\
\n\
# Wait for Xvfb to start\n\
sleep 3\n\
\n\
# Check if Xvfb is running\n\
if ! xdpyinfo -display :99 >/dev/null 2>&1; then\n\
    echo "Xvfb failed to start!"\n\
    cat /tmp/xvfb.log\n\
    exit 1\n\
fi\n\
\n\
# Set display\n\
export DISPLAY=:99\n\
\n\
# Start DBUS\n\
dbus-launch --sh-syntax > /tmp/dbus-env\n\
source /tmp/dbus-env\n\
\n\
# Start Fluxbox\n\
fluxbox >/tmp/fluxbox.log 2>&1 &\n\
\n\
# Start x11vnc\n\
x11vnc -display :99 -forever -shared -passwd secret -bg >/tmp/x11vnc.log 2>&1\n\
\n\
# Start noVNC\n\
websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &\n\
\n\
# Start Chrome with debugging\n\
google-chrome --no-sandbox --disable-gpu --window-size=1920,1080 --start-maximized --enable-logging=stderr --v=1 >/tmp/chrome.log 2>&1 &\n\
\n\
# Start xterm for debugging\n\
xterm -geometry 80x24+0+0 -e "tail -f /tmp/chrome.log" &\n\
\n\
# Show desktop apps\n\
xeyes &\n\
xclock &\n\
\n\
echo "=============================================="\n\
echo "Access Chrome GUI: http://localhost:6080/vnc.html"\n\
echo "Password: secret"\n\
echo "=============================================="\n\
echo "Debugging tools:"\n\
echo "  - Chrome logs: /tmp/chrome.log"\n\
echo "  - Xvfb logs: /tmp/xvfb.log"\n\
echo "  - Fluxbox logs: /tmp/fluxbox.log"\n\
echo "  - VNC logs: /tmp/x11vnc.log"\n\
echo "=============================================="\n\
\n\
# Keep container running\n\
tail -f /dev/null' > /usr/local/bin/start-gui.sh \
    && chmod +x /usr/local/bin/start-gui.sh

# Set default command
CMD ["/usr/local/bin/start-gui.sh"]