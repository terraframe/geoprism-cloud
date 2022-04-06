#!/bin/bash

set -e

docker run -d --network=host --rm --name=jenkins jenkins/jenkins:lts-centos7
docker run -d --network=host --rm --name=smee terraframe/smee-client:latest --url https://smee.io/9UTvMQwAiackc30s --port 8080 --path /github-webhook/
