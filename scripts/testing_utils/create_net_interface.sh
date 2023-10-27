#!/usr/bin/env bash

INT_NAME=${INTERFACE_NAME:="ocp"}

cat > /etc/sysconfig/network-scripts/ifcfg-br-${INT_NAME} <<EOF
DEVICE=br-${INT_NAME}
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=none
NM_CONTROLLED=yes
DELAY=0
EOF

systemctl restart NetworkManager
ip link add name br-${INT_NAME} type bridge || true
ip link add dummy-${INT_NAME} type dummy
ip link set dev br-${INT_NAME} up
ip link set dev dummy-{INT_NAME} master br-${INT_NAME}


