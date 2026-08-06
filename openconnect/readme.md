# openconnect-head

A Docker image built from the latest upstream [OpenConnect](https://www.infradead.org/openconnect/) source, supporting Cisco AnyConnect VPN with TOTP. Designed to be paired with a SOCKS5 proxy (e.g. [gost](https://github.com/go-gost/gost) or [microsocks](https://github.com/rofl0r/microsocks)) to expose the VPN tunnel as a local SOCKS5 proxy.

**DockerHub:** [`mawenqiandev/openconnect-head`](https://hub.docker.com/r/mawenqiandev/openconnect-head)  
**GHCR:** [`ghcr.io/ma-wenqian/openconnect-head`](https://github.com/ma-wenqian/dockerfiles/pkgs/container/openconnect-head)  
**Source:** [`ma-wenqian/dockerfiles`](https://github.com/ma-wenqian/dockerfiles/tree/main/openconnect)

The image is published to both DockerHub and GitHub Container Registry (GHCR). Use whichever you prefer — they are identical builds.

| Registry  | Image                                        |
| --------- | -------------------------------------------- |
| DockerHub | `mawenqiandev/openconnect-head:latest`       |
| GHCR      | `ghcr.io/ma-wenqian/openconnect-head:latest` |

---



## Quick Start
 
Run the setup script — it creates `.env`, `Dockerfile`, and `docker-compose.yaml` in `/opt/openconnect-head`:
 
```bash
curl -fsSL https://sh.mawenqian.com/openconnect-setup.sh | bash
```
 
Then edit `/opt/openconnect-head/.env` with your VPN details, and start it:
 
```bash
cd /opt/openconnect-head && docker compose up -d --build
```
 
Verify the SOCKS5 proxy is working:
 
```bash
curl ip.gs -x socks5h://127.0.0.1:1080
```
 
> This variant uses [microsocks](https://github.com/rofl0r/microsocks). Prefer [gost](https://github.com/go-gost/gost) instead? Use `curl -fsSL https://sh.mawenqian.com/openconnect-gost-setup.sh | bash`.
 
### LAN access (optional)
 
By default the proxy is only reachable from the host machine. If you want other devices on your local network to use it, edit `LOCAL_NETWORK` / `LOCAL_GATEWAY` in `.env` before starting the container. If only this machine will use it, leave them as-is.
 
---
 
## Environment variables
 
| Variable               | Description                                                                                                    |
| ---------------------- | -------------------------------------------------------------------------------------------------------------- |
| `OPENCONNECT_HOST`     | VPN server hostname                                                                                            |
| `OPENCONNECT_USER`     | VPN username                                                                                                   |
| `OPENCONNECT_PASSWORD` | VPN password                                                                                                   |
| `OPENCONNECT_TOTP`     | Base32 TOTP secret, for MFA — see [this guide](https://github.com/Mark4551124015/HKU-VPN) on how to extract it |
| `LOCAL_NETWORK`        | *(optional)* Subnet to route through this container                                                            |
| `LOCAL_GATEWAY`        | *(optional)* Gateway for `LOCAL_NETWORK`                                                                       |
 
---
 
## Notes
 
- Requires `NET_ADMIN` capability and `/dev/net/tun` — OpenConnect needs to create a real tun interface.
- The container auto-reconnects if the VPN session expires; restarts are expected behavior, not a bug.
- More scripts and setup guides: [sh.mawenqian.com](https://sh.mawenqian.com)