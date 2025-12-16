#!/bin/sh
#
# certbot-runner.sh (webroot / no nginx stop / idempotent cron / no double-invoke)
#
# Params (in order):
#   $1 = DOMAIN
#   $2 = EMAIL
#   $3 = KEY_PASSWORD
#   $4 = KEY_ALIAS (usually "geoprism")
#   $5 = LETSENCRYPT_PATH  (base path where `cert/` is mounted)
#   $6 = S3_BUCKET
#   $7 = S3_KEY
#   $8 = S3_SECRET
#
# REQUIREMENT:
# - nginx must serve:
#     /.well-known/acme-challenge/*
#   from a directory that maps to:
#     $LETSENCRYPT_PATH/certbot
#
# This script:
# - DOES NOT stop nginx
# - Uses certbot --webroot (HTTP-01) and requires port 80 reachable externally
# - Avoids duplicate cron entries across restarts
# - Avoids “certbot invoked twice” behavior from duplicate cron lines
# - Restarts nginx container (default: bastion) after successful issuance/renewal
#
set -eu

MODE="${1:-daemon}"
DOMAIN="${2:-}"
EMAIL="${3:-}"
KEY_PASSWORD="${4:-}"
KEY_ALIAS="${5:-}"
LETSENCRYPT_PATH="${6:-}"
S3_BUCKET="${7:-}"
S3_KEY="${8:-}"
S3_SECRET="${9:-}"

# Basic required args check
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ] || [ -z "$KEY_PASSWORD" ] || [ -z "$KEY_ALIAS" ] || [ -z "$LETSENCRYPT_PATH" ]; then
  echo "Usage: $0 MODE DOMAIN EMAIL KEY_PASSWORD KEY_ALIAS LETSENCRYPT_PATH [S3_BUCKET S3_KEY S3_SECRET]" >&2
  exit 2
fi

SERVICE_NAME="${SERVICE_NAME:-geoprism}"
NGINX_CONTAINER="${NGINX_CONTAINER:-bastion}"

# Webroot on the *host* (mounted into nginx at /var/www/certbot:ro)
WEBROOT_HOST="/var/www/certbot"
WEBROOT_CHALLENGE_DIR="${WEBROOT_HOST}/.well-known/acme-challenge"

# --- Update packages. msmtp will allow email sending via SES ---
/sbin/apk update
/sbin/apk add --no-cache certbot findutils msmtp ca-certificates

# --- msmtp config from env (SES) ---
cat >/etc/msmtprc <<EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
account        ses
host           email-smtp.${SES_REGION}.amazonaws.com
port           587
from           ${ALERT_FROM}
user           ${SES_USER}
password       ${SES_PASS}
account default : ses
EOF
chmod 600 /etc/msmtprc

notify() {
  subj="[ALERT][${SERVICE_NAME}] $1"
  body="$2"
  cat <<MAIL | msmtp -t || true
To: ${ALERT_TO}
From: ${ALERT_FROM}
Subject: ${subj}
Content-Type: text/plain

Time: $(date -Iseconds)
Host: $(hostname)
Domain: ${DOMAIN}

${body}
MAIL
}

# Wait until the mounted docker sock exists and we will symlink it for use in our container
num_sleep=0
until [ -S /var/run/parent/docker.sock ]
do
     if [ "$num_sleep" -gt 10 ]
     then
       notify "Timeout waiting for Docker socket for $DOMAIN" "Gave up after ${num_sleep}s. Exiting."
       echo "Timeout waiting for Docker socket. This program will exit. num_sleep is $num_sleep"
       exit 1
     fi
     
     echo "sleeping 1 second. current time is $num_sleep";
     sleep 1;
     
     num_sleep=$((num_sleep + 1))
done
echo "Found Docker socket. num_sleep is $num_sleep"

[ -h /var/run/docker.sock ] && unlink /var/run/docker.sock
ln -s /var/run/parent/docker.sock /var/run/docker.sock || notify "Failed to link docker.sock for $DOMAIN" ""

# Ensure webroot exists for ACME challenges (NOT under /etc/letsencrypt, so wiping letsencrypt is safe)
mkdir -p "${WEBROOT_HOST}/.well-known/acme-challenge" || true

# Move all existing SSL data somewhere else (we will delete it at the end if we're successful). This is important because the ssl certs could be for a different server if we restored an image from another server.
mkdir -p /etc/letsencrypt-backup && cp /etc/letsencrypt/cli.ini /tmp/cli.ini && mv /etc/letsencrypt/* /etc/letsencrypt-backup/ 2>/dev/null || true && mv /tmp/cli.ini /etc/letsencrypt/cli.ini

# Sleep for a little bit because our ansible script is waiting for the file to be deleted and we want to make sure they detect it here.
sleep 4

# Download the SSL data from S3
if [ -n "$S3_BUCKET" ] && [ -n "$S3_KEY" ] && [ -n "$S3_SECRET" ]; then
	docker run --rm --network host --name s3sync \
	  -e AWS_ACCESS_KEY_ID="$S3_KEY" -e AWS_SECRET_ACCESS_KEY="$S3_SECRET" \
	  -v "${LETSENCRYPT_PATH}/cert:/data" \
	  amazon/aws-cli s3 cp "s3://${S3_BUCKET}/${DOMAIN}" /data --recursive || true
else
  echo "S3 params not provided; skipping S3 download."
fi

# Rebuild live/archive symlinks if needed
if [ -x /var/lib/geoprism-certbot/rebuild_symlinks.sh ]; then
  /var/lib/geoprism-certbot/rebuild_symlinks.sh "/etc/letsencrypt" "$DOMAIN" \
    || notify "Failure rebuilding symlinks on domain $DOMAIN" "Symlink rebuild helper failed."
fi

# --- Wire hooks with runtime params ---
HOOK="/var/lib/geoprism-certbot/hooks/post-deploy.sh"
sed -i -e "s~LETSENCRYPT_PATH=.*~LETSENCRYPT_PATH=${LETSENCRYPT_PATH}~g" "$HOOK"
sed -i -e "s~DOMAIN_NAME=.*~DOMAIN_NAME=${DOMAIN}~g" "$HOOK"
sed -i -e "s~S3_BUCKET=.*~S3_BUCKET=${S3_BUCKET}~g" "$HOOK"
sed -i -e "s~S3_KEY=.*~S3_KEY=${S3_KEY}~g" "$HOOK"
sed -i -e "s~S3_SECRET=.*~S3_SECRET=${S3_SECRET}~g" "$HOOK"


# --- Certbot commands (WEBROOT / no nginx stop) ---
CERTBOT_ISSUE_CMD="certbot certonly -n --agree-tos --email \"$EMAIL\" --webroot -w \"$WEBROOT_HOST\" -d \"$DOMAIN\""
CERTBOT_RENEW_CMD="certbot renew -n --webroot -w \"$WEBROOT_HOST\""

restart_nginx() {
  # Restart is simplest and avoids needing nginx reload tooling.
  # If container isn't present, don't fail the whole script.
  (docker ps -a --format '{{.Names}}' | grep -qx "$NGINX_CONTAINER" && docker restart "$NGINX_CONTAINER") \
    || true
}

# --- First issuance (only if needed) ---
# If a cert already exists for this domain, skip certonly and rely on renew.
LIVE_CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
if [ -f "$LIVE_CERT" ]; then
  echo "Existing cert found at $LIVE_CERT; skipping initial certonly."
else
  echo "No existing cert found; attempting initial issuance via webroot."
  set +e
  ISSUE_OUTPUT="$(sh -c "$CERTBOT_ISSUE_CMD" 2>&1)"
  ISSUE_RC=$?
  set -e

  if [ "$ISSUE_RC" -ne 0 ]; then
    LOG_SNIPPET=""
    [ -f /var/log/letsencrypt/letsencrypt.log ] && LOG_SNIPPET="$(tail -n 200 /var/log/letsencrypt/letsencrypt.log)"
    notify "Critical failure getting SSL certificate on domain $DOMAIN" \
"Command:
$CERTBOT_ISSUE_CMD

Exit code: $ISSUE_RC

=== certbot output (stdout+stderr) ===
$ISSUE_OUTPUT

=== /var/log/letsencrypt/letsencrypt.log (tail) ===
$LOG_SNIPPET
"
    echo "Critical failure getting SSL certificate! Sleeping to avoid rate limits."
    cp /etc/letsencrypt/cli.ini /etc/letsencrypt-backup/cli.ini && rm -rf /etc/letsencrypt/* && mv /etc/letsencrypt-backup/* /etc/letsencrypt/ 2>/dev/null || true # Rollback
    while true; do sleep 86400; done
  fi

  if [ -x "$HOOK" ]; then
    sh "$HOOK" || notify "post-deploy failed for $DOMAIN" "post-deploy.sh returned non-zero."
  fi

  restart_nginx
fi

# --- Renew wrapper (single point of renew) ---
cat >/var/lib/geoprism-certbot/hooks/renew-wrapper.sh <<'EOF'
#!/bin/sh
set -eu

DOMAIN="${DOMAIN:-}"
NGINX_CONTAINER="${NGINX_CONTAINER:-bastion}"
HOOK="/var/lib/geoprism-certbot/hooks/post-deploy.sh"

CERTBOT_RENEW_CMD="${CERTBOT_RENEW_CMD:-}"

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
OUTPUT="$(sh -c "$CERTBOT_RENEW_CMD" 2>&1)"
RC=$?
set -e

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
EOF

chmod +x /var/lib/geoprism-certbot/hooks/renew-wrapper.sh

# --- Cron renew (daily at 00:00) - IDempotent ---
CRONLINE="0 0 * * * DOMAIN=${DOMAIN} NGINX_CONTAINER=${NGINX_CONTAINER} CERTBOT_RENEW_CMD='${CERTBOT_RENEW_CMD}' /var/lib/geoprism-certbot/hooks/renew-wrapper.sh"
grep -qxF "$CRONLINE" /etc/crontabs/root || echo "$CRONLINE" >> /etc/crontabs/root

# Wipe our cert backup (which we no longer need since this was successful)
rm -rf /etc/letsencrypt-backup

if [ "$MODE" = "oneshot" ]; then
  echo "MODE=oneshot: skipping crond -f and exiting successfully."
  exit 0
fi

# Start cron in foreground (blocks forever)
crond -f || notify "crond exited unexpectedly for $DOMAIN" ""
