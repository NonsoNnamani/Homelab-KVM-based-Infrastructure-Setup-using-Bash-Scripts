#!/bin/bash

# HostB Setup - VXLAN Bridge Project
echo "Starting HostB Setup..."

# 0. Variables (Update these with your actual values)
PHYSICAL_IP=172.28.146.37
REMOTE_IP=172.31.95.108
BRIDGE_NAME=virbr10
VNI=100

# 1. Install dependencies
sudo apt-get update
sudo apt-get install -y bridge-utils

# 2. Configure UFW Firewall
sudo ufw allow 4789/udp
sudo ufw reload

# 3. Create the VXLAN setup script for persistence
cat << 'EOF' | sudo tee /usr/local/bin/vxlan-init.sh
#!/bin/bash
# Wait for the physical interface and libvirt bridge to be ready
sleep 10

# Create VXLAN interface if it doesn't exist
if ! ip link show vxlan0 > /dev/null 2>&1; then
    ip link add vxlan0 type vxlan id $VNI remote $REMOTE_IP local $PHYSICAL_IP dstport 4789 dev eth0
    ip link set vxlan0 mtu 1450
    ip link set $BRIDGE_NAME mtu 1450
    ip link set vxlan0 up
fi

# Attach to the bridge
ip link set vxlan0 master $BRIDGE_NAME
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
ip link show vxlan0
bridge fdb show dev vxlan0
sudo ufw status verbose
echo "HostB Setup Complete. VXLAN0 is active and persistent."