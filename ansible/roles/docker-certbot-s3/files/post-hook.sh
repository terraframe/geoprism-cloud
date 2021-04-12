# https://maximilian-boehm.com/en-gb/blog/create-a-java-keystore-jks-from-lets-encrypt-certificates-1884000/

set -ex

LETSENCRYPT_PATH=/data/ssl/letsencrypt
DOMAIN_NAME=changeit
KEY_PASSWORD=changeit
KEY_ALIAS=geoprism
S3_BUCKET=XXX
S3_KEY=XXX
S3_SECRET=XXX

INTERNAL_LETSENCRYPT_PATH=/etc/letsencrypt

CERT=$(find $INTERNAL_LETSENCRYPT_PATH/archive -name "cert*.pem" -printf '%f\n' | sort -dr | head -1)
CHAIN=$(find $INTERNAL_LETSENCRYPT_PATH/archive -name "chain*.pem" -printf '%f\n' | sort -dr | head -1)
FULL_CHAIN=$(find $INTERNAL_LETSENCRYPT_PATH/archive -name "fullchain*.pem" -printf '%f\n' | sort -dr | head -1)
PRIV_KEY=$(find $INTERNAL_LETSENCRYPT_PATH/archive -name "privkey*.pem" -printf '%f\n' | sort -dr | head -1)

REGEX="cert([0-9]+)\.pem"
[[ $CERT =~ $REGEX ]]
KEY_NUM="${BASH_REMATCH[1]}"

# Convert the PEM key to a PKCS12 file containing full chain and private key
docker run --rm --name openssl-pkcs --network host \
            -v "$LETSENCRYPT_PATH/cert:/etc/letsencrypt" \
            openjdk:8-jdk-buster openssl pkcs12 -export -in \
            /etc/letsencrypt/archive/$DOMAIN_NAME/$FULL_CHAIN \
            -inkey /etc/letsencrypt/archive/$DOMAIN_NAME/$PRIV_KEY \
            -out /etc/letsencrypt/archive/$DOMAIN_NAME/pkcs$KEY_NUM.p12 \
            -name $KEY_ALIAS -password pass:$KEY_PASSWORD

# Create a keystore from the PKCS12 file
docker run --rm --name keytool-import --network host \
			-v "$LETSENCRYPT_PATH/cert:/etc/letsencrypt" \
			openjdk:8-jdk-buster \
            keytool -importkeystore -deststorepass $KEY_PASSWORD -destkeypass $KEY_PASSWORD \
            -destkeystore /etc/letsencrypt/archive/$DOMAIN_NAME/keystore$KEY_NUM.jks \
            -srckeystore /etc/letsencrypt/archive/$DOMAIN_NAME/pkcs$KEY_NUM.p12 \
            -srcstoretype PKCS12 -srcstorepass $KEY_PASSWORD -alias $KEY_ALIAS -noprompt

[ -L $INTERNAL_LETSENCRYPT_PATH/live/$DOMAIN_NAME/keystore.jks ] && unlink $INTERNAL_LETSENCRYPT_PATH/live/$DOMAIN_NAME/keystore.jks
[ -f $INTERNAL_LETSENCRYPT_PATH/live/$DOMAIN_NAME/keystore.jks ] && rm $INTERNAL_LETSENCRYPT_PATH/live/$DOMAIN_NAME/keystore.jks
ln -s ../../archive/$DOMAIN_NAME/keystore$KEY_NUM.jks $INTERNAL_LETSENCRYPT_PATH/live/$DOMAIN_NAME/keystore.jks

# Upload the new SSL key to S3 for archiving purposes
docker run --rm --network host --name s3sync \
     -e AWS_ACCESS_KEY_ID=$S3_KEY -e AWS_SECRET_ACCESS_KEY=$S3_SECRET \
     -v "$LETSENCRYPT_PATH/cert:/data" \
     amazon/aws-cli s3 cp /data s3://$S3_BUCKET/$DOMAIN_NAME --recursive

docker restart geoprism
