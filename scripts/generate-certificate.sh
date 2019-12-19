#!/usr/bin/env sh

set -e

cleanup() {
    docker rm extract-generate-certificate
}

trap 'cleanup' EXIT

if [ $# -eq 0 ]; then
    current_directory=$(dirname "$0")
else
    current_directory="$1"
fi

cd "$current_directory"/..

mkdir -p certificates
docker build -f docker/Dockerfile.generate-certificate -t generate-certificate .
docker create --name extract-generate-certificate generate-certificate
docker cp extract-generate-certificate:/src/certificates/ca.key ./certificates/ca.key
docker cp extract-generate-certificate:/src/certificates/ca.crt ./certificates/ca.crt

