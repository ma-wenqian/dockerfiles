# openconnect-head

A Docker image that runs [OpenConnect](https://www.infradead.org/openconnect/) built from upstream HEAD, exposing any AnyConnect-compatible VPN connection as a SOCKS5 proxy via [GOST](https://github.com/go-gost/gost).

**DockerHub:** [`mawenqiandev/openconnect-head`](https://hub.docker.com/r/mawenqiandev/openconnect-head)  
**GHCR:** [`ghcr.io/ma-wenqian/openconnect-head`](https://github.com/ma-wenqian/dockerfiles/pkgs/container/openconnect-head)  
**Source:** [`ma-wenqian/dockerfiles`](https://github.com/ma-wenqian/dockerfiles/tree/main/openconnect-head)

The image is published to both DockerHub and GitHub Container Registry (GHCR). Use whichever you prefer — they are identical builds.

| Registry  | Image                                        |
| --------- | -------------------------------------------- |
| DockerHub | `mawenqiandev/openconnect-head:latest`       |
| GHCR      | `ghcr.io/ma-wenqian/openconnect-head:latest` |

---

## Prerequisites

- Your VPN username and password
- Your TOTP **secret** — the Base32 seed from your authenticator app setup, **not** a live 6-digit code

> When setting up TOTP-based 2FA, the QR code encodes an `otpauth://` URI containing a `secret=` field. That Base32 string (e.g. `JBSWY3DPEHPK3PXP`) is what goes in `OPENCONNECT_TOTP`. The container generates the time-based code automatically on each connection.

---

## Usage

```bash
# from DockerHub
docker run -d \
  --name openconnect-head \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -e OPENCONNECT_HOST=vpn.example.com \
  -e OPENCONNECT_USER=your_username \
  -e OPENCONNECT_PASSWORD=your_password \
  -e OPENCONNECT_TOTP=YOUR_BASE32_SECRET \
  -p 1080:1080 \
  mawenqiandev/openconnect-head

# from GHCR
docker run -d \
  --name openconnect-head \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -e OPENCONNECT_HOST=vpn.example.com \
  -e OPENCONNECT_USER=your_username \
  -e OPENCONNECT_PASSWORD=your_password \
  -e OPENCONNECT_TOTP=YOUR_BASE32_SECRET \
  -p 1080:1080 \
  ghcr.io/ma-wenqian/openconnect-head
```

Once running, the container exposes a SOCKS5 proxy on port `1080` (default). Configure your client to use:

```
socks5://localhost:1080
```

**Test it**

```bash
curl --socks5 localhost:1080 https://example.com
```

---

## Custom Port

To use a different port, pass the `PROXY_PORT` environment variable:

```bash
docker run -d \
  --name openconnect-head \
  --cap-add NET_ADMIN \
  --device /dev/net/tun \
  -e OPENCONNECT_HOST=vpn.example.com \
  -e OPENCONNECT_USER=your_username \
  -e OPENCONNECT_PASSWORD=your_password \
  -e OPENCONNECT_TOTP=YOUR_BASE32_SECRET \
  -e PROXY_PORT=1088 \
  -p 1088:1088 \
  mawenqiandev/openconnect-head   # or ghcr.io/ma-wenqian/openconnect-head
```

---

## Docker Compose

```yaml
services:
  openconnect:
    image: mawenqiandev/openconnect-head:latest
    container_name: openconnect-head
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    environment:
      - OPENCONNECT_HOST=vpn.example.com
      - OPENCONNECT_USER=your_username
      - OPENCONNECT_PASSWORD=your_password
      - OPENCONNECT_TOTP=YOUR_BASE32_SECRET
      - PROXY_PORT=1080
    ports:
      - "1080:1080"
    restart: unless-stopped
```

---

## Environment Variables

| Variable               | Required | Default         | Description         |
| ---------------------- | -------- | --------------- | ------------------- |
| `OPENCONNECT_USER`     | **Yes**  | —               | VPN username        |
| `OPENCONNECT_PASSWORD` | **Yes**  | —               | VPN password        |
| `OPENCONNECT_TOTP`     | **Yes**  | —               | Base32 TOTP secret  |
| `OPENCONNECT_HOST`     | No       | `vpn2fa.hku.hk` | VPN server hostname |
| `PROXY_PORT`           | No       | `1080`          | SOCKS5 proxy port   |

---

## Notes

- `--cap-add NET_ADMIN` and `--device /dev/net/tun` are required for OpenConnect to create a TUN interface
- Credentials are passed via environment variables — do not commit them to version control. Use a `.env` file with `--env-file` or Docker secrets
- The SOCKS5 proxy has no authentication. Bind to `127.0.0.1` or use a firewall rule if running on a non-local machine
- OpenConnect is built from the upstream Git `HEAD` — bypassing the outdated version in distribution package repositories