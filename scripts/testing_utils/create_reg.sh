#!/usr/bin/env bash

# make sure to run this only after the `default` libvirt network becomes available i.e after 3_setup_kvm_host.yaml has been run for the first time. After that you can run it again to refresh registry

set -xe
echo "Preparing for disconnected install"
export REGISTRY_NAME="test_reg"
export REGISTRY_PORT=5000
export REGISTRY_USERNAME="testuser"
export REGISTRY_PASSWORD="testpassword"
export DATA_DIR="/var/lib/libvirt/registry"
export REGISTRY_DOMAIN="registry.tt.testing"
export PULL_SECRET_FILE="$HOME/ocp-pull-secret.json"
export GO_GZ_URL="https://dl.google.com/go/go1.20.5.linux-s390x.tar.gz"
export REGISTRY_IMAGE="docker.io/ibmcom/registry-s390x:2.6.2.5"
export REGISTRY_IP="192.168.122.1"

[[ ! -f $PULL_SECRET_FILE ]] && echo "Please create $PULL_SECRET_FILE with your Red Hat pull secrets"

yum -y install podman httpd-tools

[[ -d /usr/local/go ]] && rm -rf /usr/local/go
curl -s $GO_GZ_URL  | tar -xzf - -C /usr/local
export PATH=$PATH:/usr/local/go/bin
echo "export PATH=\$PATH:/usr/local/go/bin" >> /etc/bashrc
go version

if ! command -v yq &> /dev/null; then
  [[ -z $GOBIN ]] && export GOBIN="$(go env GOPATH)/bin"
  [[ ! -d $GOBIN ]] && mkdir -p $GOBIN
  ls $GOBIN/yq || go install github.com/mikefarah/yq/v4@latest
  export PATH=$PATH:$GOBIN
  if ! cat /etc/bashrc | grep $GOBIN; then
    echo "export PATH=\$PATH:$GOBIN" >> /etc/bashrc
  fi
fi

podman stop $REGISTRY_NAME || true
podman rm -f $REGISTRY_NAME || true
rm -rf $DATA_DIR/data && mkdir -p  $DATA_DIR/data
[[ ! -d $DATA_DIR/auth ]]& mkdir -p $DATA_DIR/auth
[[ ! -d $DATA_DIR/certs ]] && mkdir -p $DATA_DIR/certs
[[ ! -d $DATA_DIR/secret ]] && mkdir -p $DATA_DIR/secret

if ! cat /etc/NetworkManager/conf.d/openshift.conf | grep dnsmasq; then
	echo -e "[main]\ndns=dnsmasq" | tee /etc/NetworkManager/conf.d/openshift.conf
	systemctl restart NetworkManager
	systemctl restart firewalld
	sleep 2
fi

htpasswd -bBc ${DATA_DIR}/auth/htpasswd ${REGISTRY_USERNAME} ${REGISTRY_PASSWORD}
export DISCONNECTED_SECRET="$(echo -n "${REGISTRY_USERNAME}:${REGISTRY_PASSWORD}" | base64 -w0)"
cat > $DATA_DIR/secret/cluster.json <<EOF
{"auths":{"${REGISTRY_DOMAIN}:${REGISTRY_PORT}":{"auth":"${DISCONNECTED_SECRET}","email":"testuser@example.com"}}}
EOF

cp -f $PULL_SECRET_FILE $DATA_DIR/secret/mirror.json
yq -i '.auths."'${REGISTRY_DOMAIN}':'${REGISTRY_PORT}'"={}' -o json $DATA_DIR/secret/mirror.json
yq -i '.auths."'${REGISTRY_DOMAIN}':'${REGISTRY_PORT}'".auth="'${DISCONNECTED_SECRET}'"' -o json $DATA_DIR/secret/mirror.json
yq -i  '.auths."'${REGISTRY_DOMAIN}':'${REGISTRY_PORT}'".email="testuser@example.com"'  -o json $DATA_DIR/secret/mirror.json

cat > /etc/NetworkManager/dnsmasq.d/registry.conf <<EOF
server=/tt.testing/${REGISTRY_IP}
address=/.registry.tt.testing/${REGISTRY_IP}
EOF
systemctl restart NetworkManager

if [[ ! -f $DATA_DIR/certs/san.conf ]]; then
	cat > $DATA_DIR/certs/san.conf <<EOF
[req]
default_bits  = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
OU = Self-signed certificate
CN = ${REGISTRY_DOMAIN}

[req_ext]
subjectAltName = @alt_names

[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, cRLSign, keyCertSign, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${REGISTRY_DOMAIN}
EOF

fi

pushd $DATA_DIR/certs
[[ ! -f registry.key ]] && openssl genrsa 2048 > registry.key && chmod 440 registry.key
[[ ! -f registry.crt ]] && openssl req -new -x509 -nodes -sha1 -days 365 -key registry.key -out registry.crt -config san.conf
popd

cp -f $DATA_DIR/certs/registry.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust

firewall-cmd --add-port=$REGISTRY_PORT/tcp --zone=internal --permanent
firewall-cmd --add-port=$REGISTRY_PORT/tcp --zone=public   --permanent

# If you get permission issues, especially w.r.t .so files, add  `--privileged` flag to below command
podman run --name $REGISTRY_NAME -p $REGISTRY_PORT:5000 \
     -v $DATA_DIR/data:/var/lib/registry:z \
     -v $DATA_DIR/auth:/auth:z \
     -e "REGISTRY_AUTH=htpasswd" \
     -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
     -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
     -v $DATA_DIR/certs:/certs:z \
     -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
     -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
     -d ${REGISTRY_IMAGE}
sleep 5
curl -u $REGISTRY_USERNAME:$REGISTRY_PASSWORD https://$REGISTRY_DOMAIN:$REGISTRY_PORT/v2/_catalog
sleep 2
rm -rf /etc/pki/ca-trust/source/anchors/registry.crt
update-ca-trust
set +x
echo
echo "-------------CLUSTER PULL SECRET-------------"
echo
cat $DATA_DIR/secret/cluster.json
echo
echo "-------------MIRROR PULL SECRET-------------"
echo
cat $DATA_DIR/secret/mirror.json
echo
echo "-------------CA CERT-------------"
echo
cat $DATA_DIR/certs/registry.crt
echo
echo "DONE"
exit 0
