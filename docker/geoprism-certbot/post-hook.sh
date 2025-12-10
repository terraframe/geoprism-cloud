# post-hook.sh
set -e

DOMAIN_NAME=changeit
KEY_PASSWORD=changeit
KEY_ALIAS=geoprism

# Convert PEM→PKCS12
docker run --rm --name openssl-pkcs --network host \
  -v "/data/ssl/letsencrypt/cert:/etc/letsencrypt" \
  eclipse-temurin:8-jdk openssl pkcs12 -export -in \
  /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem \
  -inkey /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem \
  -out /etc/letsencrypt/live/$DOMAIN_NAME/pkcs.p12 \
  -name $KEY_ALIAS -password pass:$KEY_PASSWORD \
  || /var/lib/geoprism-certbot/hooks/error-notify.sh "post-hook failed: openssl pkcs12"

# Create keystore
docker run --rm --name keytool-import --network host \
  -v "/data/ssl/letsencrypt/cert:/etc/letsencrypt" \
  eclipse-temurin:8-jdk \
  keytool -importkeystore -deststorepass $KEY_PASSWORD -destkeypass $KEY_PASSWORD \
  -destkeystore /etc/letsencrypt/live/$DOMAIN_NAME/keystore.jks \
  -srckeystore /etc/letsencrypt/live/$DOMAIN_NAME/pkcs.p12 \
  -srcstoretype PKCS12 -srcstorepass $KEY_PASSWORD -alias $KEY_ALIAS -noprompt \
  || /var/lib/geoprism-certbot/hooks/error-notify.sh "post-hook failed: keytool import"

docker restart geoprism || /var/lib/geoprism-certbot/hooks/error-notify.sh "post-hook failed: restart geoprism"
