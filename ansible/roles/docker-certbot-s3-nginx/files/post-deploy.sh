#!/bin/sh

set -ex

LETSENCRYPT_PATH=/data/ssl/letsencrypt
DOMAIN_NAME=changeit
S3_BUCKET=XXX
S3_KEY=XXX
S3_SECRET=XXX

INTERNAL_LE_PATH=/etc/letsencrypt

[ ! -d $INTERNAL_LE_PATH/archive/$DOMAIN_NAME ] && echo "Exiting because the archive directory does not contain our domain" && exit 0

# Upload the new SSL key to S3 for archiving purposes
docker run --rm --network host --name s3sync \
     -e AWS_ACCESS_KEY_ID=$S3_KEY -e AWS_SECRET_ACCESS_KEY=$S3_SECRET \
     -v "$LETSENCRYPT_PATH/cert:/data" \
     amazon/aws-cli s3 cp /data s3://$S3_BUCKET/$DOMAIN_NAME --recursive \
     || /var/lib/geoprism-certbot/hooks/error-notify.sh "post-hook failed: s3 archive for $DOMAIN_NAME"
