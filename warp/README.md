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

## Start the container

### 1. TUN Mode

If you want to route traffic through the virtual `tun` interface, the container requires advanced network privileges. You can run **Gost** (or similar tools) alongside WARP inside the container to expose a proxy port.

**From Docker Hub:**

```bash
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 \
  --restart unless-stopped \
  mawenqiandev/warp

```

**From GitHub Container Registry (GHCR):**

```bash
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 \
  --restart unless-stopped \
  ghcr.io/ma-wenqian/warp

```

---

### 2. Proxy Mode (No TUN Required)

If you do not need the `tun` device, you can run WARP in its built-in proxy mode (typically SOCKS5). This does not require `--cap-add NET_ADMIN`.

```bash
docker run -d \
  --name warp \
  -p 1081:1081 \
  --restart unless-stopped \
  mawenqiandev/warp

```

**💡 Advanced Usage: Forwarding with Gost**
By default, WARP's proxy mode runs on a specific internal port (e.g., `40000`). While you can map this directly using Docker's `-p` flag, you can also use **Gost** to forward the traffic. This is highly recommended if you need to:

* Convert protocols (e.g., from SOCKS5 to HTTP proxy).
* Add username/password authentication.
* Specify a custom external port.

*Example Gost command routing traffic to WARP's local SOCKS5 proxy:*

```bash
gost -L=http://:1081 -F=socks5://127.0.0.1:40000

```

*(Note: Replace `40000` with the actual default port your WARP client is listening on).*

---


for tun use, you can add gost or other to start a proxy prot.

```bash
# from DockerHub
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 --restart unless-stopped \
  mawenqiandev/warp

# from GHCR
docker run -d \
  --name warp \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -p 1081:1081 --restart unless-stopped \
  ghcr.io/ma-wenqian/warp
```

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

## Notes

- `--cap-add NET_ADMIN` and `--device /dev/net/tun` are required for WARP to create a TUN interface
- The proxy protocol is HTTP by default. To switch to SOCKS5, change `http://` to `socks5://` in the `Dockerfile` entrypoint and rebuild
- Registration data is stored inside the container. To persist it across container recreations, mount `/var/lib/cloudflare-warp` as a volume