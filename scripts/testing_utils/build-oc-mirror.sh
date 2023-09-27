#!/usr/bin/env bash

CLIENTS_DIR="clients"

set -e
subscription-manager register
git clone https://github.com/openshift/oc-mirror
pushd oc-mirror
podman build -f Dockerfile -t local/go-toolset .
podman run -it --rm --privileged -v ${PWD}:/build:z local/go-toolset
pushd bin
file oc-mirror
./oc-mirror -h
tar -czf oc-mirror.tar.gz oc-mirror
popd
cp -avrf bin/oc-mirror.tar.gz /var/www/html/$CLIENTS_DIR/oc-mirror.tar.gz
popd
rm -rf oc-mirror


