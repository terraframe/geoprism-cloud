
# Params (in order) for running this script are:
# $1 = CERT_PATH
# $2 = DOMAIN

set -ex

[ -d $1/live ] && rm -r $1/live

[ ! -d $1/archive/$2 ] && echo "Exiting because the archive directory does not contain our domain" && exit 0

mkdir -p $1/live/$2

CERT=$(find $1/archive/$2 -name "cert*.pem" -printf '%f\n' | sort -dr | head -1)
CHAIN=$(find $1/archive/$2 -name "chain*.pem" -printf '%f\n' | sort -dr | head -1)
FULL_CHAIN=$(find $1/archive/$2 -name "fullchain*.pem" -printf '%f\n' | sort -dr | head -1)
PRIV_KEY=$(find $1/archive/$2 -name "privkey*.pem" -printf '%f\n' | sort -dr | head -1)
KEYSTORE=$(find $1/archive/$2 -name "keystore*.jks" -printf '%f\n' | sort -dr | head -1)

ln -s ../../archive/$2/$CERT $1/live/$2/cert.pem
ln -s ../../archive/$2/$CHAIN $1/live/$2/chain.pem
ln -s ../../archive/$2/$FULL_CHAIN $1/live/$2/fullchain.pem
ln -s ../../archive/$2/$PRIV_KEY $1/live/$2/privkey.pem
ln -s ../../archive/$2/$KEYSTORE $1/live/$2/keystore.jks
