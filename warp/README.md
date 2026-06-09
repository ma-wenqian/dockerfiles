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

## First-Time Setup

WARP requires a one-time registration before it can connect. On the very first run you must enter the container and register manually.

**Step 1 — Start the container**

```bash
# from DockerHub
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 \
  mawenqiandev/warp

# from GHCR
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 \
  ghcr.io/ma-wenqian/warp
```

**Step 2 — Enter the container and register**

```bash
docker exec -it warp bash
warp-cli registration new
exit
```

**Step 3 — Restart to apply**

```bash
docker restart warp
```

After this, the container will connect to WARP automatically on every future start. No need to register again.

---

## Usage

Once running, the container exposes an HTTP proxy on port `1081` (default).

Configure your client to use:

```
http://localhost:1081
```

**Test it**

```bash
curl -x http://localhost:1081 https://cloudflare.com/cdn-cgi/trace
```

Look for `warp=on` in the output to confirm WARP is active.

---

## Custom Port

To use a different port, pass the `PROXY_PORT` environment variable:

```bash
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -e PROXY_PORT=8080 \
  -p 8080:8080 \
  mawenqiandev/warp   # or ghcr.io/ma-wenqian/warp
```

---

## Docker Compose

```yaml
services:
  warp:
    image: mawenqiandev/warp:latest
    container_name: warp
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - PROXY_PORT=1081
    ports:
      - "1081:1081"
    restart: unless-stopped
```

---

## Notes

- `--cap-add NET_ADMIN` and `--device /dev/net/tun` are required for WARP to create a TUN interface
- The proxy protocol is HTTP by default. To switch to SOCKS5, change `http://` to `socks5://` in the `Dockerfile` entrypoint and rebuild
- Registration data is stored inside the container. To persist it across container recreations, mount `/var/lib/cloudflare-warp` as a volume