#!/usr/bin/env bash

CLIENTS_DIR="clients"

set -e
yum -y install wget
pushd /var/www/html/$CLIENTS_DIR/
wget https://mirror.openshift.com/pub/openshift-v4/s390x/clients/ocp-dev-preview/candidate-4.14/oc-mirror.tar.gz
popd
