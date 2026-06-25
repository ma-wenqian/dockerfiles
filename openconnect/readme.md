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
    volumes:
      - /usr/local/bin/vpn:/usr/local/bin/vpn:ro
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
      --useragent="AnyConnect" -l --timestamp &&
      echo "OpenConnect connection experied. Restarting ..." 
      vpn restart' 

  gost:
    image: gogost/gost:latest
    container_name: gost
    restart: unless-stopped
    network_mode: "service:opcvpn"
    environment:
      GOST_LOGGER_LEVEL: fatal
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
    volumes:
      - /usr/local/bin/vpn:/usr/local/bin/vpn:ro
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
      --useragent="AnyConnect" -l --timestamp &&
      echo "OpenConnect connection experied. Restarting ..." 
      vpn restart' 
  warp:
    image: mawenqiandev/warp:latest
    container_name: warp
    restart: unless-stopped
    network_mode: "service:opcvpn"
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
    network_mode: "service:opcvpn"
    environment:
      GOST_LOGGER_LEVEL: fatal
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

### Script

#### Setup
  Please modify the relevate folder names and container names

```
chmod +x ~/docker/vpn/vpn.sh
sudo ln -s ~/docker/vpn/vpn.sh /usr/local/bin/vpn
```

#### Usage

```
Usage:
  vpn [option]

Available Options:
  restart     - Restart all VPN containers (docker compose restart)
  stop        - Stop all VPN containers
  start       - Start all VPN containers
  remove      - Remove all VPN containers and networks (docker compose down)
  logs        - Show docker logs for hkuvpn container
  status      - Show docker ps status for hkuvpn, gost, and warp containers
  help        - Display this help message

Examples:
  vpn restart
  vpn stop
  vpn logs
  vpn status
```

```
#!/bin/bash
# VPN Management Script for hkuvpn Docker Compose
# Usage: vpn [option]

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
COMPOSE_DIR="$(dirname "${SCRIPT_PATH}")"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yaml"
CONTAINERS=("hkuvpn" "gost" "warp")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display help/usage information
show_help() {
    echo -e "${BLUE}VPN Management Command${NC}\n"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  vpn [option]\n"
    echo -e "${YELLOW}Available Options:${NC}"
    echo -e "  ${GREEN}restart${NC}     - Restart all VPN containers (docker compose restart)"
    echo -e "  ${GREEN}stop${NC}        - Stop all VPN containers"
    echo -e "  ${GREEN}start${NC}       - Start all VPN containers"
    echo -e "  ${GREEN}remove${NC}      - Remove all VPN containers and networks (docker compose down)"
    echo -e "  ${GREEN}logs${NC}        - Show docker logs for hkuvpn container"
    echo -e "  ${GREEN}status${NC}      - Show docker ps status for hkuvpn, gost, and warp containers"
    echo -e "  ${GREEN}help${NC}        - Display this help message\n"
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  vpn restart"
    echo -e "  vpn stop"
    echo -e "  vpn logs"
    echo -e "  vpn status\n"
}

# Restart containers
restart_containers() {
    echo -e "${BLUE}[*] Restarting Docker Compose containers...${NC}"
    cd "${COMPOSE_DIR}" || exit 1
    docker compose stop
    docker compose restart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Containers restarted successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to restart containers${NC}"
        exit 1
    fi
}

# Stop containers
stop_containers() {
    echo -e "${BLUE}[*] Stopping Docker Compose containers...${NC}"
    cd "${COMPOSE_DIR}" || exit 1
    docker compose stop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Containers stopped successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to stop containers${NC}"
        exit 1
    fi
}

# Start containers
start_containers() {
    echo -e "${BLUE}[*] Starting Docker Compose containers...${NC}"
    cd "${COMPOSE_DIR}" || exit 1
    docker compose down
    docker compose up -d
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Containers started successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to start containers${NC}"
        exit 1
    fi
}

# Remove containers
remove_containers() {
    echo -e "${BLUE}[*] Removing Docker Compose containers and networks...${NC}"
    cd "${COMPOSE_DIR}" || exit 1
    docker compose down
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Containers removed successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to remove containers${NC}"
        exit 1
    fi
}

# Show logs
show_logs() {
    echo -e "${BLUE}[*] Showing latest logs for hkuvpn container...${NC}"
    docker logs --tail 50 hkuvpn
}

# Show status
show_status() {
    echo -e "${BLUE}[*] Docker container status:${NC}"
    echo ""
    local filter_args=""
    for container in "${CONTAINERS[@]}"; do
        filter_args+="--filter name=$container "
    done
    docker ps -a $filter_args --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
    echo ""
}

# Main script logic
case "${1:-}" in
    restart)
        restart_containers
        ;;
    stop)
        stop_containers
        ;;
    start)
        start_containers
        ;;
    remove)
        remove_containers
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        echo -e "${RED}[✗] Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

```

### Notes

- All three containers (`warp`, `gost`, `opcvpn`) share the same network namespace. `ports` is therefore declared only on `opcvpn`.
- WARP runs in proxy mode and listens on `127.0.0.1:1085`. Since all containers share `localhost`, gost can reach it directly.
- The `-F` flag applies globally to gost, meaning both `-L` listeners forward through WARP. If you want `:1080` to route through the VPN TUN only (no `-F`), run two separate gost containers — one per listener.
- OpenConnect is built from the upstream Git `HEAD` — bypassing the outdated version in distribution package repositories




