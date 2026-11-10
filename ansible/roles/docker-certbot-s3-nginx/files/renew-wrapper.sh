#!/bin/sh
set -eu

DOMAIN="${DOMAIN:-}"
NGINX_CONTAINER="${NGINX_CONTAINER:-bastion}"
HOOK="/var/lib/geoprism-certbot/hooks/post-deploy.sh"

notify_fail() {
  TITLE="$1"

  if [ -x /var/lib/geoprism-certbot/hooks/error-notify.sh ]; then
    /bin/sh /var/lib/geoprism-certbot/hooks/error-notify.sh "$TITLE"
  fi
}

# Certbot runs this only when a certificate was actually renewed.
DEPLOY_HOOK="docker kill --signal=HUP '$NGINX_CONTAINER'"

if [ -x "$HOOK" ]; then
  DEPLOY_HOOK="sh '$HOOK' && $DEPLOY_HOOK"
fi

set +e
OUTPUT="$(
  certbot renew \
    -n \
    --webroot \
    -w /var/www/certbot \
    --deploy-hook "$DEPLOY_HOOK" \
    2>&1
)"
RC=$?
set -e

echo "$OUTPUT"

if [ "$RC" -ne 0 ]; then
  printf '%s\n' "$OUTPUT" |
    notify_fail "Renewal failed for ${DOMAIN} (exit ${RC})"

  exit "$RC"
fi

exit 0