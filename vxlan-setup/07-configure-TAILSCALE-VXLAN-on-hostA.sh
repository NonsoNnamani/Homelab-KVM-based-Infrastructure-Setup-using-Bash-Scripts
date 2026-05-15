#!/bin/bash

# HostA Setup - VXLAN Bridge Project
echo "Starting HostA Setup..."

# 1. Install dependencies
sudo apt-get update
sudo apt-get install -y bridge-utils

# 2. Configure UFW Firewall
sudo ufw allow 4789/udp
sudo ufw reload

# 3. Create the VXLAN setup script for persistence
cat << 'EOF' | sudo tee /usr/local/bin/vxlan-init.sh
#!/bin/bash

# Variables (Update these with your actual values)
PHYSICAL_IP=100.114.18.30
REMOTE_IP=100.71.37.76
VIRTUAL_BRIDGE=virbr10
VXLAN_INTERFACE=vxlan0
VNI=100
# Wait for the physical interface and libvirt bridge to be ready
sleep 10

# Create VXLAN interface if it doesn't exist using NEW MTU for Tailscale compatibility
if ! ip link show $VXLAN_INTERFACE > /dev/null 2>&1; then
    ip link add $VXLAN_INTERFACE type vxlan id $VNI remote $REMOTE_IP local $PHYSICAL_IP dstport 4789 dev tailscale0
    ip link set $VXLAN_INTERFACE mtu 1230
    ip link set $VIRTUAL_BRIDGE mtu 1230
    ip link set $VXLAN_INTERFACE up
fi

# Attach to the bridge
ip link set $VXLAN_INTERFACE master $VIRTUAL_BRIDGE
EOF

sudo chmod +x /usr/local/bin/vxlan-init.sh

# 4. Create Systemd Service for Persistence
cat << 'EOF' | sudo tee /etc/systemd/system/vxlan-tunnel.service
[Unit]
Description=VXLAN Tunnel Persistence
After=network-online.target libvirtd.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vxlan-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable and Start
sudo systemctl enable --now vxlan-tunnel.service

# 6. Verify VXLAN Interface
ip link show $VXLAN_INTERFACE
bridge fdb show dev $VXLAN_INTERFACE
sudo ufw status verbose
echo "HostA Setup Complete. $VXLAN_INTERFACE is active and persistent."