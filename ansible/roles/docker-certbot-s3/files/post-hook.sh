#!/bin/sh

set -e

docker start geoprism || docker restart geoprism || true
