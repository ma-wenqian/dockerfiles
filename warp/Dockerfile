FROM ubuntu:24.04

ENV TZ=Asia/Hong_Kong

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

CMD ["warp-svc"]