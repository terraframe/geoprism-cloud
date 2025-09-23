#!/bin/sh

# Designed for Alpine Linx with Busybox shell (standard docker-in-docker image)
# apk is the package manager (like apt-get) in Alpine Linux

# Params (in order) for running this script are:
# $1 = DOMAIN
# $2 = EMAIL
# $3 = KEY_PASSWORD
# $4 = KEY_ALIAS (usually just "geoprism")
# $5 = S3_BUCKET
# $6 = S3_KEY
# $7 = S3_SECRET
# $8 = LETSENCRYPT_PATH

set -e

DOMAIN="$1"

# --- Update packages. msmtp will allow email sending via SES ---
/sbin/apk update
/sbin/apk add --no-cache certbot findutils msmtp ca-certificates

# Create msmtp config from env (SES)
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
  subj="[ALERT][${SERVICE_NAME:-geoprism}] $1"
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

# Delete all existing SSL data
yes | cp /etc/letsencrypt/cli.ini /etc/letsencrypt/../cli.ini && rm -rf /etc/letsencrypt/* && mv /etc/letsencrypt/../cli.ini /etc/letsencrypt/cli.ini

# Sleep for a little bit because our ansible script is waiting for the file to be deleted and we want to make sure they detect it here.
sleep 8

# Download the SSL data from S3
docker run --rm --network host --name s3sync \
     -e AWS_ACCESS_KEY_ID=$6 -e AWS_SECRET_ACCESS_KEY=$7 \
     -v "$8/cert:/data" \
     amazon/aws-cli s3 cp s3://$5/$1 /data --recursive

/var/lib/geoprism-certbot/rebuild_symlinks.sh "/etc/letsencrypt" "$1" || notify "Failure rebuilding symlinks on domain $DOMAIN" "Failure rebuilding symlinks on domain $DOMAIN"


CERTBOT_CMD="certbot certonly -n --standalone -d $1 --agree-tos --email $2 --http-01-port 8080"

# --- Wire hooks with runtime params ---
sed -i -e "s~LETSENCRYPT_PATH=.*~LETSENCRYPT_PATH=$8~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~KEY_PASSWORD=.*~KEY_PASSWORD=$3~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~KEY_ALIAS=.*~KEY_ALIAS=$4~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~DOMAIN_NAME=.*~DOMAIN_NAME=$1~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~S3_BUCKET=.*~S3_BUCKET=$5~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~S3_KEY=.*~S3_KEY=$6~g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s~S3_SECRET=.*~S3_SECRET=$7~g" /var/lib/geoprism-certbot/hooks/post-hook.sh

# --- First issuance (or forced renew) ---
if ! eval "$CERTBOT_CMD" ; then
  # Include last 200 lines of certbot log if available
  LOG_SNIPPET=""
  [ -f /var/log/letsencrypt/letsencrypt.log ] && LOG_SNIPPET="$(tail -n 200 /var/log/letsencrypt/letsencrypt.log)"
  notify "Critical failure getting SSL certificate on domain $DOMAIN" "$LOG_SNIPPET"
  echo "Critical failure getting SSL certificate! Sleeping so as to avoid fetching more certs and hitting a rate limit."
  while true; do sleep 86400; done
fi

# Try to bounce app container; notify if it fails but don't die
(docker top geoprism && echo "Rebooting geoprism to update certificate" && docker restart geoprism) \
  || echo "Did not restart geoprism" "Likely not running or missing."

# --- Cron renew (daily at 00:00) ---
echo "00    00       *       *       *       $CERTBOT_CMD || ( echo 'renew failed' && tail -n 200 /var/log/letsencrypt/letsencrypt.log | sed 's/^/LOG: /' | logger ; /bin/sh -c \"/var/lib/geoprism-certbot/hooks/error-notify.sh 'Renewal failed for $1'\" )" >> /etc/crontabs/root

crond -f || notify "crond exited unexpectedly for $DOMAIN" ""
