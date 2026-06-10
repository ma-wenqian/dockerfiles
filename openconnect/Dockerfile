# Stage 1: Build OpenConnect from upstream HEAD
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    git build-essential autoconf automake libtool pkg-config \
    libgnutls28-dev libxml2-dev libproxy-dev liblz4-dev libstoken-dev \
    ca-certificates vpnc-scripts zlib1g-dev gettext \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 git://git.infradead.org/users/dwmw2/openconnect.git . \
    && ./autogen.sh \
    && ./configure --with-vpnc-script=/usr/share/vpnc-scripts/vpnc-script \
    && make -j$(nproc) \
    && make install


# Stage 2: Runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libxml2 libproxy1v5 libstoken1 \
    vpnc-scripts curl ca-certificates iproute2 iptables \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local
COPY --from=gogost/gost:latest /bin/gost /usr/local/bin/gost

RUN ldconfig

# Required VPN credentials
ENV OPENCONNECT_HOST=vpn2fa.hku.hk
ENV OPENCONNECT_USER=
ENV OPENCONNECT_PASSWORD=
ENV OPENCONNECT_TOTP=

# Allow customizing the proxy port, defaults to 1080
ENV PROXY_PORT=1080

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE ${PROXY_PORT}

ENTRYPOINT ["/entrypoint.sh"]