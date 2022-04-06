#!/bin/bash

# Run with elevated 'sudo' permissions as necessary

set -e

# If tag is not set, then set it to 'latest' as a default value.
tag=${tag:-'latest'}

rm -rf smee-client-docker || true
git clone https://github.com/deltaprojects/smee-client-docker.git

cd smee-client-docker
docker build --no-cache -t terraframe/smee-client:$tag .

if [ "$tag" != "latest" ]; then
  docker tag terraframe/smee-client:$tag terraframe/smee-client:latest
fi
