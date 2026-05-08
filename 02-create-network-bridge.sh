#!/usr/bin/env bash

set -euo pipefail

NETWORK_NAME="k8s-net1"
BRIDGE_NAME="virbr10"
XML_FILE="$HOME/${NETWORK_NAME}.xml"

echo "Creating libvirt network definition: ${XML_FILE}"

cat <<EOF | tee "${XML_FILE}" >/dev/null
<network>
  <name>$NETWORK_NAME</name>
  <forward mode='nat'/>
  <bridge name='$BRIDGE_NAME' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.10.10.50' end='10.10.10.200'/>
    </dhcp>
  </ip>
</network>
EOF

echo "Defining libvirt network..."
sudo virsh net-define "${XML_FILE}"

echo "Starting network..."
sudo virsh net-start "${NETWORK_NAME}"

echo "Enabling autostart..."
sudo virsh net-autostart "${NETWORK_NAME}"

echo
echo "Network '${NETWORK_NAME}' created successfully."

echo
echo "Current network status:"
sudo virsh net-list --all