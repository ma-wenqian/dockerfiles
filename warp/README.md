# warp

A Docker image that runs [Cloudflare WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/) as a background daemon and exposes it as an HTTP proxy via [GOST](https://github.com/go-gost/gost).

**DockerHub:** [`mawenqiandev/warp`](https://hub.docker.com/r/mawenqiandev/warp)  
**GHCR:** [`ghcr.io/ma-wenqian/warp`](https://github.com/ma-wenqian/dockerfiles/pkgs/container/warp)  
**Source:** [`ma-wenqian/dockerfiles`](https://github.com/ma-wenqian/dockerfiles/tree/main/warp)

The image is published to both DockerHub and GitHub Container Registry (GHCR). Use whichever you prefer — they are identical builds.

| Registry  | Image                            |
| --------- | -------------------------------- |
| DockerHub | `mawenqiandev/warp:latest`       |
| GHCR      | `ghcr.io/ma-wenqian/warp:latest` |

---

## Start the container|warp-gost-proxy

Route your traffic through [Cloudflare WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/) using Docker, and expose it as a local SOCKS5 proxy via [gost](https://github.com/go-gost/gost).

Two setups are provided depending on how you run WARP:

|                              | Solution 1 — Proxy Mode                | Solution 2 — TUN Mode                          |
| ---------------------------- | -------------------------------------- | ---------------------------------------------- |
| WARP runs as                 | SOCKS5 proxy on `127.0.0.1:1085`       | Full TUN virtual network interface             |
| gost role                    | Bridges `127.0.0.1:1085` → port `1081` | Listens on `1081`, traffic auto-routed via TUN |
| `cap_add` / `devices` needed | No                                     | Yes (`NET_ADMIN`, `/dev/net/tun`)              |
| Complexity                   | Lower                                  | Higher, but routes all traffic                 |

---

## Solution 1 — WARP Proxy Mode

WARP runs as a SOCKS5 proxy on `127.0.0.1:1085` inside its container. Since it binds to loopback, gost must share the same network namespace via `network_mode: service:warp` to reach it.

```
Your machine :1081  →  gost  →  127.0.0.1:1085  →  WARP  →  Cloudflare
```

### `docker-compose.yml`

```yaml
services:
  warp:
    image: mawenqiandev/warp:latest
    container_name: warp
    restart: unless-stopped
    ports:
      - "1081:1081" # Owned by warp's network namespace, shared with gost
    command: >
      sh -c "
        warp-svc >/dev/null &

        sleep 3

        warp-cli --accept-tos mode proxy &&
        warp-cli --accept-tos proxy port 1085 &&
        warp-cli --accept-tos registration delete || true &&
        warp-cli --accept-tos registration new &&
        warp-cli --accept-tos connect &&

        sleep 30

        echo 'WARP connected. Testing...' &&
        curl -x 127.0.0.1:1085 -sL  https://cloudflare.com/cdn-cgi/trace | grep warp ||

        echo 'WARP test failed'

        tail -f /dev/null
      "
      
  gost:
    image: gogost/gost:latest
    container_name: gost
    restart: unless-stopped
    network_mode: "service:warp" # Share warp's network namespace so 127.0.0.1 is reachable
    environment:
      GOST_LOGGER_LEVEL: fatal
    depends_on:
      - warp
    command: "-L=:1081/127.0.0.1:1085" # Listen on 1081, expose as SOCKS5, Forward to warp's local proxy port
```

### Usage

```bash
docker compose up -d
```

Then configure your application to use `socks5://127.0.0.1:1081` as the proxy, or test with curl:

```bash
curl --proxy socks5h://127.0.0.1:1081 https://cloudflare.com/cdn-cgi/trace
```

You should see `warp=on` in the output.

---

## Solution 2 — WARP TUN Mode

WARP creates a virtual TUN network interface that captures all traffic at the OS level. gost shares this network namespace, so any traffic it sends is automatically routed through WARP — no explicit `-F` forward needed.

```
Your machine :1081  →  gost  →  [TUN interface]  →  WARP  →  Cloudflare
```

### `docker-compose.yml`

```yaml
services:
  warp:
    image: mawenqiandev/warp:latest
    container_name: warp
    restart: unless-stopped
    cap_add:
      - NET_ADMIN  # Required for TUN device
    devices:
      - /dev/net/tun:/dev/net/tun  # TUN interface
    sysctls:
      - net.ipv4.ip_forward=1  # Allow traffic forwarding

  gost:
    image: gogost/gost:latest
    container_name: gost
    restart: unless-stopped
    network_mode: "service:warp" # All gost traffic routes through warp's TUN interface
    environment:
      GOST_LOGGER_LEVEL: fatal
    depends_on:
      - warp
    ports:
      - "1081:1081"
    command:
      - "-L=:1081" # Listen and expose as SOCKS5, no -F needed — TUN handles routing
```

### Usage

```bash
docker compose up -d
```

Same as Solution 1 — connect to `socks5://127.0.0.1:1081`:

```bash
curl --proxy socks5h://127.0.0.1:1081 https://cloudflare.com/cdn-cgi/trace
```

> **Note:** TUN mode requires `/dev/net/tun` to be available on your host. This works on most Linux systems. It may require additional setup on Docker Desktop (macOS/Windows).

---

## Notes

- The `ports` declaration must always be on the `warp` service, not `gost`, because `network_mode: service:warp` means gost shares warp's network stack and has no independent port bindings.
- Verify that the `mawenqiandev/warp` image exposes its proxy on port `1085` in proxy mode — check its documentation or set `WARP_PROXY_PORT=1085` via environment variables if needed.
- Neither setup exposes WARP's internal port externally, keeping the attack surface minimal.
