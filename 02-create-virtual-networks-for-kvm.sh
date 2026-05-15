#!/usr/bin/env bash

set -euo pipefail

NETWORK_NAME="k8s-net"
VIRTUAL_BRIDGE="virbr10"
XML_FILE="$HOME/${NETWORK_NAME}.xml"

echo "Creating libvirt network definition: ${XML_FILE}"

cat <<EOF | tee "${XML_FILE}" >/dev/null
<network>
  <name>$NETWORK_NAME</name>
  <forward mode='nat'/>
  <bridge name='$VIRTUAL_BRIDGE' stp='on' delay='0'/>
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



: <<'PLEASE_NOTE'
This script creates a new libvirt network named "k8s-net" with NAT forwarding and a DHCP range. 
It defines the network using an XML file, starts it, and sets it to autostart on boot. 
Finally, it lists all networks to confirm the new network is active.

To connect 2 Hosts using VXLAN, remember to do the following >>>

1. Configuration for HostA
Keep the bridge IP as .1, but limit its DHCP range to the first half of the subnet.
==========================
XML
<!-- virsh net-edit k8s-net -->
<ip address='10.10.10.1' netmask='255.255.255.0'>
  <dhcp>
    <range start='10.10.10.50' end='10.10.10.124'/>
  </dhcp>
</ip>


2. Configuration for HostB
Change the bridge IP to .2 (so it doesn't conflict with HostA) and set the DHCP range to the second half.
==========================
XML
<!-- virsh net-edit k8s-net -->
<ip address='10.10.10.2' netmask='255.255.255.0'>
  <dhcp>
    <range start='10.10.10.125' end='10.10.10.200'/>
  </dhcp>
</ip>


Why This Works
No Conflicts: Even if a VM on HostB accidentally gets its IP from HostA (which can happen!), the IP will still be unique.
Redundancy: If the DHCP service on HostA goes down, HostB will still be there to hand out addresses to everyone.
Routing: VMs will use whichever bridge they are locally attached to as their default gateway, but they can still "see" the other bridge at .1 or .2.

PLEASE_NOTE