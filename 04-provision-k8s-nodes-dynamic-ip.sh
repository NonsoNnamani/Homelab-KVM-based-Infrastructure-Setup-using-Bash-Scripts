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
    "k8s-master1:4096:2:60G"
    "k8s-master2:4096:2:60G"
    "k8s-master3:4096:2:60G"
    "k8s-worker1:8192:4:100G"
    "k8s-worker2:8192:4:100G"
)

NETWORK=k8s-net

for node in "${nodes[@]}"; do
    IFS=":" read -r NAME RAM CPU DISK <<< "$node"
    
    echo "--- Deploying $NAME ---"

    # FIXED: #cloud-config MUST be the first line
    echo "#cloud-config" > "${NAME}-user-data"
    echo "hostname: $NAME" >> "${NAME}-user-data"
    echo "fqdn: ${NAME}.local" >> "${NAME}-user-data"
    # Use 'tail' to skip the first line (#cloud-config) of your template to avoid duplicates
    tail -n +2 "$USER_DATA_TEMPLATE" >> "${NAME}-user-data"

    echo "instance-id: $NAME" > meta-data
    echo "local-hostname: $NAME" >> meta-data

    # Create Cloud-Init ISO
    sudo cloud-localds "/var/lib/libvirt/images/${NAME}-seed.iso" "${NAME}-user-data" meta-data

    # Create Copy-on-Write Disk
    sudo qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "/var/lib/libvirt/images/${NAME}.qcow2" "$DISK"
    
    # Launch VM
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

    rm "${NAME}-user-data" meta-data
done