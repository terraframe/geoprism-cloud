#!/bin/bash
# Run with elevated 'sudo' permissions as necessary

set -e

docker build -t tfbuilder:$1 .

docker tag tfbuilder:$1 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:$1

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 961902606948.dkr.ecr.us-west-2.amazonaws.com

if [ "$1" != "latest" ]; then
  docker tag tfbuilder:$1 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:latest
  docker push 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:$1
fi

docker push 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:latest
