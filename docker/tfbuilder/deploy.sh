#!/bin/bash
# Run with elevated 'sudo' permissions as necessary

set -e

docker build -t tfbuilder .

docker tag tfbuilder:latest 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:latest

eval $(aws ecr get-login --region us-west-2 --no-include-email)
docker push 961902606948.dkr.ecr.us-west-2.amazonaws.com/tfbuilder:latest
