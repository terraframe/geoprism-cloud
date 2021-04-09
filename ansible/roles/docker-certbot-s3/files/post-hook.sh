
# https://maximilian-boehm.com/en-gb/blog/create-a-java-keystore-jks-from-lets-encrypt-certificates-1884000/

DOMAIN_NAME=changeit
KEY_PASSWORD=changeit
KEY_ALIAS=geoprism
S3_BUCKET=XXX
S3_KEY=XXX
S3_SECRET=XXX

# Convert the PEM key to a PKCS12 file containing full chain and private key
docker run --rm --name openssl-pkcs --network host \
            -v "/data/ssl/letsencrypt/cert:/etc/letsencrypt" \
            openjdk:8-jdk-buster openssl pkcs12 -export -in \
            /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem \
            -inkey /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem \
            -out /etc/letsencrypt/live/$DOMAIN_NAME/pkcs.p12 \
            -name $KEY_ALIAS -password pass:$KEY_PASSWORD

# Create a keystore from the PKCS12 file
docker run --rm --name keytool-import --network host \
			-v "/data/ssl/letsencrypt/cert:/etc/letsencrypt" \
			openjdk:8-jdk-buster \
            keytool -importkeystore -deststorepass $KEY_PASSWORD -destkeypass $KEY_PASSWORD \
            -destkeystore /etc/letsencrypt/live/$DOMAIN_NAME/keystore.jks \
            -srckeystore /etc/letsencrypt/live/$DOMAIN_NAME/pkcs.p12 \
            -srcstoretype PKCS12 -srcstorepass $KEY_PASSWORD -alias $KEY_ALIAS -noprompt

# Upload the new SSL key to S3 for archiving purposes
docker run -rm --name s3sync \
     -e AWS_ACCESS_KEY_ID=$S3_KEY -e AWS_SECRET_ACCESS_KEY=$S3_SECRET \
     elementar/s3-volume /data s3://$S3_BUCKET/$DOMAIN_NAME

docker restart geoprism
