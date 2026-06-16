#!/bin/sh

gost -L :1080 > /var/log/gost1.log 2>&1 &

# Required envs (strict, simplified)
OPENCONNECT_HOST=${OPENCONNECT_HOST:-}
OPENCONNECT_USER=${OPENCONNECT_USER:-}
OPENCONNECT_PASSWORD=${OPENCONNECT_PASSWORD:-}
OPENCONNECT_TOTP=${OPENCONNECT_TOTP:-}


echo "${OPENCONNECT_PASSWORD}" | openconnect --protocol=anyconnect "https://${OPENCONNECT_HOST}/" \
    -u "${OPENCONNECT_USER}" \
    --passwd-on-stdin --force-dpd=30 \
    --token-mode=totp \
    --token-secret=base32:${OPENCONNECT_TOTP} \
    --useragent="AnyConnect -b -l --timestamp"

tail -f /dev/null