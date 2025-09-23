#!/bin/sh
set -e

MSG_SUBJECT="$1"
# Reuse msmtp config created by entrypoint
if [ ! -f /etc/msmtprc ]; then
  echo "msmtp config missing; cannot send alert" >&2
  exit 0
fi

# Pull some recent certbot logs if present
LOG_SNIPPET=""
[ -f /var/log/letsencrypt/letsencrypt.log ] && LOG_SNIPPET="$(tail -n 200 /var/log/letsencrypt/letsencrypt.log)"

cat <<MAIL | msmtp -t || true
To: ${ALERT_TO}
From: ${ALERT_FROM}
Subject: [ALERT][${SERVICE_NAME:-geoprism}] ${MSG_SUBJECT}
Content-Type: text/plain

Time: $(date -Iseconds)
Host: $(hostname)
Details:
${LOG_SNIPPET}
MAIL
