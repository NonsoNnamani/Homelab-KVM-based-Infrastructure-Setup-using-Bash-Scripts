#!/bin/bash

IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
BASE_IMG="/var/lib/libvirt/images/noble-base.img"
USER_DATA_TEMPLATE="user-data.yaml"

# 1. Download base image if not present
if [ ! -f "$BASE_IMG" ]; then
    sudo wget -O "$BASE_IMG" "$IMAGE_URL"
fi

sudo chown libvirt-qemu:libvirt-qemu "$BASE_IMG"
sudo chmod 644 "$BASE_IMG"

# 2. Define the nodes: "name:ram:vcpus:disk:static_ip"
nodes=(
    "k8s-master1:4096:2:60G:10.10.10.10"
    "k8s-master2:4096:2:60G:10.10.10.11"
    "k8s-master3:4096:2:60G:10.10.10.12"
    "k8s-worker1:8192:4:120G:10.10.10.20"
    "k8s-worker2:8192:4:120G:10.10.10.21"
)

GATEWAY="10.10.10.1"
NAMESERVER="8.8.8.8, 1.1.1.1"
NETWORK=k8s-net

for node in "${nodes[@]}"; do
    IFS=":" read -r NAME RAM CPU DISK IP <<< "$node"
    
    echo "--- Deploying $NAME with IP $IP ---"

    # A. Create User-Data (Credentials & Hostname)
    echo "#cloud-config" > "${NAME}-user-data"
    echo "hostname: $NAME" >> "${NAME}-user-data"
    tail -n +2 "$USER_DATA_TEMPLATE" >> "${NAME}-user-data"

    # B. Create Network-Config (Static IP)
    # Note: 'enp1s0' is the standard default for KVM/Virtio, check your bridge if different
    cat <<EOF > "${NAME}-network-config"
network:
  version: 2
  ethernets:
    enp1s0:
      addresses:
        - $IP/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$NAMESERVER]
EOF

    # C. Create Meta-data
    echo "instance-id: $NAME" > meta-data
    echo "local-hostname: $NAME" >> meta-data

    # D. Create Cloud-Init ISO (Now including -n for network-config)
    sudo cloud-localds "/var/lib/libvirt/images/${NAME}-seed.iso" \
        "${NAME}-user-data" \
        meta-data \
        --network-config "${NAME}-network-config"

    # E. Create Disk and Launch (Same as before)
    sudo qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "/var/lib/libvirt/images/${NAME}.qcow2" "$DISK"
    
    sudo virt-install \
      --name "$NAME" \
      --memory "$RAM" \
      --vcpus "$CPU" \
      --os-variant ubuntu24.04 \
      --disk "path=/var/lib/libvirt/images/${NAME}.qcow2,device=disk" \
      --disk "path=/var/lib/libvirt/images/${NAME}-seed.iso,device=cdrom" \
      --import \
      --network network=$NETWORK \
      --noautoconsole \
      --graphics none

    # Cleanup
    rm "${NAME}-user-data" "${NAME}-network-config" meta-data
done