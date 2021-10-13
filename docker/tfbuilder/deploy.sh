#!/bin/bash
# Run with elevated 'sudo' permissions as necessary

set -e

docker build -t tfbuilder .

docker tag tfbuilder:nonroot 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:nonroot

aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 961902606948.dkr.ecr.us-west-2.amazonaws.com
docker push 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:nonroot
