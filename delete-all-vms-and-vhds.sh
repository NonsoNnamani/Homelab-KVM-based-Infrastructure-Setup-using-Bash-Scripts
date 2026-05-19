#!/bin/bash
#
# delete-all-vms-and-vhds.sh
# Removes all VMs, VHDs, and OS image files
# inside /var/lib/libvirt/images.
#

set -e

IMG_DIR="/var/lib/libvirt/images"

echo "=== STEP 1: Destroying all running VMs ==="
for vm in $(virsh list --name); do
    echo "Destroying VM: $vm"
    virsh destroy "$vm"
done

echo "=== STEP 2: Undefining all VMs (remove storage) ==="
for vm in $(virsh list --all --name); do
    echo "Undefining VM: $vm"
    virsh undefine "$vm" --remove-all-storage
done

echo "=== STEP 3: Cleaning up leftover image files ==="
FILES=$(find "$IMG_DIR" -maxdepth 1 -type f)

if [[ -n "$FILES" ]]; then
    echo "Deleting leftover files in $IMG_DIR..."
    for f in $FILES; do
        echo "Deleting: $f"
        sudo rm -f "$f"
    done
else
    echo "No leftover image files found."
fi

sudo ls -lashrt "$IMG_DIR"

echo "=== CLEANUP COMPLETE ==="
