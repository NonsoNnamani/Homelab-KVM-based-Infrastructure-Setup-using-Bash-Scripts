#!/bin/bash
echo "Starting VXLAN Rollback..."

VIRTUAL_BRIDGE="virbr10"
VXLAN_INTERFACE="vxlan0"

# 1. Stop and Disable the Systemd Service
sudo systemctl stop vxlan-tunnel.service
sudo systemctl disable vxlan-tunnel.service

# 2. Remove the Persistence Files
sudo rm -f /etc/systemd/system/vxlan-tunnel.service
sudo rm -f /usr/local/bin/vxlan-init.sh
sudo systemctl daemon-reload

# 3. Tear down the Virtual Network Interface
if ip link show $VXLAN_INTERFACE > /dev/null 2>&1; then
    sudo ip link delete $VXLAN_INTERFACE
    echo "$VXLAN_INTERFACE interface removed."
fi

# 4. Reset Bridge MTU back to standard (1500)
# Replace 'virbr10' if your bridge name is different
sudo ip link set $VIRTUAL_BRIDGE mtu 1500

# 5. Remove Firewall Rule
sudo ufw delete allow 4789/udp
sudo ufw reload

echo "Rollback Complete. All settings have been reverted."