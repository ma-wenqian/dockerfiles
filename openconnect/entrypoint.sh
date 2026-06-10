#!/bin/sh
log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }

log "Starting HKU VPN gateway"

# Required envs
if [ -z "$OPENCONNECT_USER" ] || [ -z "$OPENCONNECT_PASSWORD" ] || [ -z "$OPENCONNECT_TOTP" ]; then
    log "ERROR: OPENCONNECT_USER, OPENCONNECT_PASSWORD, and OPENCONNECT_TOTP must be set"
    tail -f /dev/null
fi

# Start GOST SOCKS5 proxy in the background on the configured port
log "Starting GOST proxy on port ${PROXY_PORT}..."
gost -L socks5://:${PROXY_PORT} > /var/log/gost.log 2>&1 &

log "Connecting to ${OPENCONNECT_HOST} as ${OPENCONNECT_USER}"
printf '%s\n' "${OPENCONNECT_PASSWORD}" | openconnect --protocol=anyconnect "https://${OPENCONNECT_HOST}/" \
    -u "${OPENCONNECT_USER}" \
    --passwd-on-stdin \
    --token-mode=totp \
    --token-secret=base32:${OPENCONNECT_TOTP} \
    --useragent="AnyConnect" 2>&1 | while read -r line; do log "[VPN] $line"; done

log "VPN process exited — entering sleep to avoid crash-loop"
tail -f /dev/null
