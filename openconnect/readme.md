# openconnect-head

A Docker image built from the latest upstream [OpenConnect](https://www.infradead.org/openconnect/) source, supporting Cisco AnyConnect VPN with TOTP. Designed to be paired with [gost](https://github.com/go-gost/gost) to expose the VPN tunnel as a local SOCKS5 proxy.

**DockerHub:** [`mawenqiandev/openconnect-head`](https://hub.docker.com/r/mawenqiandev/openconnect-head)  
**GHCR:** [`ghcr.io/ma-wenqian/openconnect-head`](https://github.com/ma-wenqian/dockerfiles/pkgs/container/openconnect-head)  
**Source:** [`ma-wenqian/dockerfiles`](https://github.com/ma-wenqian/dockerfiles/tree/main/openconnect-head)

The image is published to both DockerHub and GitHub Container Registry (GHCR). Use whichever you prefer — they are identical builds.

| Registry  | Image                                        |
| --------- | -------------------------------------------- |
| DockerHub | `mawenqiandev/openconnect-head:latest`       |
| GHCR      | `ghcr.io/ma-wenqian/openconnect-head:latest` |

---


## Quick Start

### `.env`

```env
OPENCONNECT_HOST=vpn.yourcompany.com
OPENCONNECT_USER=yourname
OPENCONNECT_PASSWORD=yourpassword
OPENCONNECT_TOTP=YOURTOTPBASE32SECRET
```

---

## Example 1 — OpenConnect + gost

The simplest setup. Connects to your VPN and exposes it as a SOCKS5 proxy on port `1080`.

```
Your machine :1080  →  gost  →  [TUN interface]  →  Corporate VPN
```

```yaml
services:

  opcvpn:
    image: mawenqiandev/openconnect-head:latest
    container_name: opcvpn
    restart: unless-stopped
    network_mode: "bridge"
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "1080:1080"
    env_file:
      - .env
    command: >
      sh -c '
      mkdir -p /etc/vpnc/post-connect.d &&
      echo "ip route add 10.0.0.0/24 via 172.17.0.1" > /etc/vpnc/post-connect.d/add-routes.sh &&
      chmod +x /etc/vpnc/post-connect.d/add-routes.sh &&
      echo "$$OPENCONNECT_PASSWORD" | openconnect --protocol=anyconnect
      "https://$$OPENCONNECT_HOST/"
      -u "$$OPENCONNECT_USER"
      --passwd-on-stdin --force-dpd=30
      --token-mode=totp
      --token-secret=base32:$$OPENCONNECT_TOTP
      --useragent="AnyConnect" -l --timestamp'

  gost:
    image: gogost/gost:latest
    container_name: gost
    restart: unless-stopped
    network_mode: "service:opcvpn"
    environment:
      GOST_LOGGER_LEVEL: warn
    depends_on:
      - opcvpn
    command:
      - "-L=:1080"
```

### Usage

```bash
docker compose up -d
```

Connect your app or browser to `socks5://127.0.0.1:1080`, or test with curl:

```bash
curl --proxy socks5h://127.0.0.1:1080 https://ifconfig.me
```

You should see your corporate VPN's egress IP.

### Notes

- The `ip route add` line in the command is written to `/etc/vpnc/post-connect.d/add-routes.sh` and executed automatically by OpenConnect after the tunnel is up. Adjust the subnet and gateway to match your network.
- Remove or replace that line if you don't need custom routes.
- `ports` is declared on `opcvpn`, not `gost`, because gost shares opcvpn's network namespace via `network_mode: service:opcvpn`.

---

## Example 2 — OpenConnect + WARP + gost

Adds a [Cloudflare WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/) container into the same network namespace. This gives you two independent proxy ports:

- `:1080` → Corporate VPN
- `:1081` → Cloudflare WARP (public internet)

```
Your machine :1080  →  gost  →  [TUN interface]  →  Corporate VPN
Your machine :1081  →  gost  →  127.0.0.1:1085   →  WARP  →  Cloudflare →  Corporate VPN
```

A bonus effect: WARP's continuous keepalive traffic helps prevent the OpenConnect session from timing out due to inactivity.

```yaml
services:

  opcvpn:
    image: mawenqiandev/openconnect-head:latest
    container_name: opcvpn
    network_mode: "bridge"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "1080:1080"
      - "1081:1081"
    env_file:
      - .env
    command: >
      sh -c '
      mkdir -p /etc/vpnc/post-connect.d &&
      echo "ip route add 10.0.0.0/24 via 172.17.0.1" > /etc/vpnc/post-connect.d/add-routes.sh &&
      chmod +x /etc/vpnc/post-connect.d/add-routes.sh &&
      echo "$$OPENCONNECT_PASSWORD" | openconnect --protocol=anyconnect
      "https://$$OPENCONNECT_HOST/"
      -u "$$OPENCONNECT_USER"
      --passwd-on-stdin --force-dpd=30
      --token-mode=totp
      --token-secret=base32:$$OPENCONNECT_TOTP
      --useragent="AnyConnect" -l --timestamp'
  warp:
    image: mawenqiandev/warp:latest
    container_name: warp
    restart: unless-stopped
    network_mode: "service:opcvpn"

  gost:
    image: gogost/gost:latest
    container_name: gost
    restart: unless-stopped
    network_mode: "service:opcvpn"
    environment:
      GOST_LOGGER_LEVEL: warn
    depends_on:
      - opcvpn
      - warp
    command:
      - "-L=:1080"
      - "-L=:1081/127.0.0.1:1085"
```

### Usage

```bash
docker compose up -d
```

| Proxy                     | Routes through  |
| ------------------------- | --------------- |
| `socks5://127.0.0.1:1080` | Corporate VPN   |
| `socks5://127.0.0.1:1081` | Cloudflare WARP |

Test each:

```bash
# VPN
curl --proxy socks5h://127.0.0.1:1080 https://ifconfig.me

# WARP
curl --proxy socks5h://127.0.0.1:1081 https://cloudflare.com/cdn-cgi/trace
# warp=on should appear in the output
```

### Notes

- All three containers (`warp`, `gost`, `opcvpn`) share the same network namespace. `ports` is therefore declared only on `opcvpn`.
- WARP runs in proxy mode and listens on `127.0.0.1:1085`. Since all containers share `localhost`, gost can reach it directly.
- The `-F` flag applies globally to gost, meaning both `-L` listeners forward through WARP. If you want `:1080` to route through the VPN TUN only (no `-F`), run two separate gost containers — one per listener.
- OpenConnect is built from the upstream Git `HEAD` — bypassing the outdated version in distribution package repositories




