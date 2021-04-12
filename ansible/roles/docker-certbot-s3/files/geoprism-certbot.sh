
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

/sbin/apk update
/sbin/apk add certbot
/sbin/apk add findutils

# Wait until the mounted docker sock exists and we will symlink it for use in our container
num_sleep=0
until [ -S /var/run/parent/docker.sock ]
do
     if [ "$num_sleep" -gt 10 ]
     then
       echo "Timeout waiting for Docker socket. This program will exit. num_sleep is $num_sleep"
       exit 1
     fi
     
     echo "sleeping 1 second. current time is $num_sleep";
     sleep 1;
     
     num_sleep=$((num_sleep + 1))
done
echo "Found Docker socket. num_sleep is $num_sleep"

[ -h /var/run/docker.sock ] && unlink /var/run/docker.sock
ln -s /var/run/parent/docker.sock /var/run/docker.sock


# Download the SSL data from S3
docker run --rm --network host --name s3sync \
     -e AWS_ACCESS_KEY_ID=$6 -e AWS_SECRET_ACCESS_KEY=$7 \
     -v "$8/cert:/data" \
     amazon/aws-cli s3 cp s3://$5/$1 /data --recursive

/var/lib/geoprism-certbot/rebuild_symlinks.sh "/etc/letsencrypt" "$1"


CERTBOT_CMD="certbot certonly -n --standalone -d $1 --agree-tos --email $2 --http-01-port 8080"

sed -i -e "s/LETSENCRYPT_PATH=.*/LETSENCRYPT_PATH=$8/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/KEY_PASSWORD=.*/KEY_PASSWORD=$3/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/KEY_ALIAS=.*/KEY_ALIAS=$4/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/DOMAIN_NAME=.*/DOMAIN_NAME=$1/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/S3_BUCKET=.*/S3_BUCKET=$5/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/S3_KEY=.*/S3_KEY=$6/g" /var/lib/geoprism-certbot/hooks/post-hook.sh
sed -i -e "s/S3_SECRET=.*/S3_SECRET=$7/g" /var/lib/geoprism-certbot/hooks/post-hook.sh

eval "$CERTBOT_CMD" || echo "Critical failure getting SSL certificate! Sleeping so as to avoid fetching more certs and hitting a rate limit." && while true; do sleep 86400; done

echo "00    00       *       *       *       $CERTBOT_CMD" >> /etc/crontabs/root

crond -f
