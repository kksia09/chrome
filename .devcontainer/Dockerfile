FROM node:20-bullseye

# Install dependencies (OS and Chrome prerequisites)
RUN apt-get update && apt-get install -y \
    ca-certificates fonts-liberation libappindicator3-1 libasound2 \
    libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 \
    libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 \
    libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 \
    libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 \
    lsb-release wget xdg-utils xvfb fluxbox x11vnc novnc websockify \
    dbus-x11 x11-apps net-tools git build-essential

# Install Chrome
RUN wget -O /tmp/chrome.deb \
      https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
 && apt install -y /tmp/chrome.deb \
 && rm /tmp/chrome.deb

# Clone Automa, install dependencies, build, and apply ajv fix
RUN git clone https://github.com/AutomaApp/automa.git /opt/automa \
 && cd /opt/automa \
 && echo "legacy-peer-deps=true" > .npmrc \
 && npm install --legacy-peer-deps \
 && npm install --save-dev ajv@^7 \
 && npm install ajv-keywords@latest mini-css-extract-plugin@2.4.2 --no-save \
 && npm run build

# Copy startup script
COPY start-gui.sh /usr/local/bin/start-gui.sh
RUN chmod +x /usr/local/bin/start-gui.sh

CMD ["/usr/local/bin/start-gui.sh"]
