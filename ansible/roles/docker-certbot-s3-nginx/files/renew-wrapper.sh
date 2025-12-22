#!/bin/sh
set -eu

DOMAIN="${DOMAIN:-}"
NGINX_CONTAINER="${NGINX_CONTAINER:-bastion}"
HOOK="/var/lib/geoprism-certbot/hooks/post-deploy.sh"

notify_fail() {
  # error-notify.sh should exist in your image; it should read stdin
  TITLE="$1"
  if [ -x /var/lib/geoprism-certbot/hooks/error-notify.sh ]; then
    /bin/sh /var/lib/geoprism-certbot/hooks/error-notify.sh "$TITLE"
  fi
}

restart_nginx() {
  (docker ps -a --format '{{.Names}}' | grep -qx "$NGINX_CONTAINER" && docker restart "$NGINX_CONTAINER") || true
}

# Run renew once, capture output
set +e
OUTPUT="$(certbot renew -n --webroot -w /var/www/certbot 2>&1)"
RC=$?
set -e

echo "$OUTPUT"

if [ "$RC" -ne 0 ]; then
  printf '%s\n' "$OUTPUT" | notify_fail "Renewal failed for ${DOMAIN} (exit ${RC})"
  exit "$RC"
fi

# If certbot reports no renewal needed, OUTPUT contains that; still harmless to restart.
# Run post-deploy hook if present (keystore/s3 sync/etc.)
if [ -x "$HOOK" ]; then
  sh "$HOOK" >/dev/null 2>&1 || true
fi

restart_nginx
exit 0