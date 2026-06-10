FROM ubuntu:24.04

# Non-interactive mode to prevent prompts during installation (e.g. timezone)
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies, add Cloudflare WARP repo, install warp, and clean up
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    ca-certificates \
    iptables \
    && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && . /etc/os-release \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends cloudflare-warp tinyproxy\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


ENV TZ=Asia/Hong_Kong

# Allow customizing the proxy port, defaults to 1081
ENV PROXY_PORT=1081

COPY tinyproxy.conf /etc/tinyproxy.conf

# Write the entrypoint script inline
RUN echo '#!/bin/bash\n\
# 1. Start warp-svc daemon in the background\n\
warp-svc > /dev/null 2>&1 &\n\
\n\
# 2. Wait until warp-svc is ready\n\
until warp-cli status > /dev/null 2>&1; do\n\
    sleep 0.5\n\
done\n\
\n\
# 3. Set mode and connect\n\
# If already registered (e.g. from an imported image), registration is skipped\n\
echo y | warp-cli registration new || true\n\
warp-cli connect\n\
\n\
# 4. Patch tinyproxy port and start in foreground\n\
sed -i "s/^Port .*/Port ${PROXY_PORT}/" /etc/tinyproxy.conf\n\
exec tinyproxy -c /etc/tinyproxy.conf -d' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE ${PROXY_PORT}

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]