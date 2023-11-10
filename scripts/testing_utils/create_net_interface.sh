#!/usr/bin/env bash

export INT_NAME=${INTERFACE_NAME:="ocp"}
export IPV4_INT_ADDRESS=${IPV4_INT_ADDRESS?=please provide ipv4 interface address}
export IPV4_START=${IPV4_START?=please provide starting ipv4 address}
export IPV4_END="${IPV4_END?=please provide ending ipv4 address}"
export IPV4_NETMASK="${IPV4_NETMASK?=please provide ipv4 net mask}"
export IPV6_INT_ADDRESS=${IPV6_INT_ADDRESS?=please provide ipv6 interface address}
export IPV6_PREFIX=${IPV6_PREFIX?=please provide ipv6 prefix}
export BR_NAME="br-${INT_NAME}"
export DUMMY_NAME="dummy-${INT_NAME}"

cat > /etc/sysconfig/network-scripts/ifcfg-${BR_NAME} <<EOF
DEVICE=${BR_NAME}
TYPE=Bridge
ONBOOT=yes
BOOTPROTO=none
NM_CONTROLLED=yes
DELAY=0
EOF

systemctl restart NetworkManager
ip link add name ${BR_NAME} type bridge || true
ip link add ${DUMMY_NAME} type dummy
ip link set dev ${BR_NAME} up
ip link set dev {DUMMY_NAME} master ${BR_NAME}

cat > ${INT_NAME}.xml <<EOF
<network>
  <name>${INT_NAME}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='${BR_NAME}' stp='on' delay='0'/>
  <ip address='${IPV4_INT_ADDRESS}' netmask='${IPV4_NETMASK}'>
    <dhcp>
      <range start='${IPV4_START}' end='${IPV4_END}'/>
    </dhcp>
  </ip>
  <ip family="ipv6" address="${IPV6_INT_ADDRESS}" prefix="${IPV6_PREFIX}"
</network>
EOF
