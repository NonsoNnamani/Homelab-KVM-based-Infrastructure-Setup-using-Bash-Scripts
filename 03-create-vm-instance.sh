#!/bin/bash

# --- Configuration ---
VAR_FILE="userdata-var.yaml"
TEMPLATE="userdata-cloud-init.yaml.tpl"
OUTPUT="/tmp/userdata-cloud-init.yaml"

HOSTNAME=$(yq '.HOSTNAME' "$VAR_FILE")
NAME=$(yq '.NAME' "$VAR_FILE")
SSH_KEY=$(yq '.SSH_KEY' "$VAR_FILE")
PASSWORD_HASH=$(yq '.PASSWORD_HASH' "$VAR_FILE")
ADDRESS_CIDR=$(yq '.ADDRESS_CIDR' "$VAR_FILE")
GATEWAY4=$(yq '.GATEWAY4' "$VAR_FILE")
DISK_SIZE=$(yq '.DISK_SIZE' "$VAR_FILE")
BRIDGE_NAME=$(yq '.BRIDGE_NAME' "$VAR_FILE")

export HOSTNAME NAME SSH_KEY PASSWORD_HASH ADDRESS_CIDR GATEWAY4 DISK_SIZE BRIDGE_NAME
envsubst '$HOSTNAME $NAME $SSH_KEY $PASSWORD_HASH $ADDRESS_CIDR $GATEWAY4 $DISK_SIZE $BRIDGE_NAME' < "$TEMPLATE" > "$OUTPUT"


VM_NAME=$HOSTNAME
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
SOURCE_IMG="noble-server-cloudimg-amd64.img"
DEST_IMG="/var/lib/libvirt/images/${VM_NAME}.qcow2"
DISK_SIZE="$DISK_SIZE"
USER_DATA="$OUTPUT"

echo "Checking environment..."

# 1. Download only if source file doesn't exist locally
if [ ! -f "$SOURCE_IMG" ]; then
    echo "Downloading Ubuntu Noble cloud image..."
    wget -q --show-progress "$IMAGE_URL"
else
    echo "Source image '$SOURCE_IMG' already exists."
fi

# 2. Provision disk only if destination doesn't exist
if [ ! -f "$DEST_IMG" ]; then
    echo "Provisioning new disk to $DEST_IMG..."
    sudo mv "$SOURCE_IMG" "$DEST_IMG"
    sudo qemu-img resize "$DEST_IMG" "$DISK_SIZE"
    sudo chown libvirt-qemu:libvirt-qemu "$DEST_IMG"
else
    echo "Disk '$DEST_IMG' already exists."
fi

# 3. Launch VM only if it does not already exist in libvirt
if ! virsh list --all | grep -q "\s$VM_NAME\s"; then
    echo "Creating VM: $VM_NAME..."
    sudo virt-install \
      --name "$VM_NAME" \
      --ram 4096 \
      --vcpus 4 \
      --cpu host \
      --disk path="$DEST_IMG",format=qcow2,size=50,bus=virtio \
      --os-variant ubuntu24.04 \
      --network network=$BRIDGE_NAME,model=virtio \
      --graphics none \
      --console pty,target_type=serial \
      --cloud-init user-data="$USER_DATA" \
      --import \
      --noautoconsole
    echo "VM $VM_NAME started."
else
    echo "VM '$VM_NAME' already exists. Use 'virsh start $VM_NAME' if it is shut off."
fi
