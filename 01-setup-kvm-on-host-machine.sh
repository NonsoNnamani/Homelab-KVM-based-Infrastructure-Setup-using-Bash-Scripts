#!/bin/bash

# KVM Virtualization Setup Script
# This script automates the installation and configuration of KVM on Ubuntu/Debian systems.

set -e

echo "=== KVM Setup Script ==="

# 1. Update the system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
echo "Installing cpu-checker..."
sudo apt install -y cpu-checker
echo "Running kvm-ok check..."
kvm-ok

# 2. Check for hardware virtualization support
echo "Checking for CPU virtualization support (VT-x/AMD-V)..."
VIRT_COUNT=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ "$VIRT_COUNT" -eq 0 ]; then
    echo "ERROR: No virtualization support detected. Please enable VT-x/AMD-V in your BIOS/UEFI and reboot."
    exit 1
fi
echo "Virtualization support detected."

# 3. Install KVM and related packages
echo "Installing KVM, libvirt, and related tools... Installed separately because of dependencies "
## Check Ubuntu version to determine which qemu package to install
VERSION=$(lsb_release -rs) && \
{ [ "$VERSION" = "26.04" ] && sudo apt install -y qemu-system-x86-hwe; } || \
{ [ "$VERSION" = "24.04" ] && sudo apt install -y qemu-system-x86; }

# Continue installing KVM and related packages
sudo apt install -y libvirt-daemon-system
sudo apt install -y libvirt-clients
sudo apt install -y bridge-utils
sudo apt install -y virtinst
sudo apt install -y virt-manager
sudo apt install -y ovmf
sudo apt install -y cloud-image-utils
sudo apt install -y libguestfs-tools
sudo apt install -y qemu-utils
sudo apt install -y libosinfo-bin
sudo apt install -y wget
sudo apt update && sudo apt install -y
  
# 4. Enable and start the libvirt daemon
echo "Enabling and starting libvirtd service..."
sudo systemctl enable --now libvirtd
sudo systemctl status libvirtd --no-pager -l

# 5. Add user to groups
echo "Adding user '$USER' to kvm and libvirt groups..."
sudo usermod -aG kvm,libvirt "$USER"
echo "NOTE: You must log out and log back in (or run 'newgrp libvirt') for group changes to take effect."

# 6. Verify installation
echo "Verifying installation..."
echo "--- Checking KVM modules ---"
lsmod | grep kvm || echo "Warning: KVM modules not loaded yet (reboot may be required)"

echo "--- Checking libvirt network status ---"
sudo virsh net-list --all

# Attempt to start and autostart the default network if it exists
if sudo virsh net-list --inactive | grep -q "default"; then
    echo "Starting default network..."
    sudo virsh net-start default
    echo "Setting default network to autostart..."
    sudo virsh net-autostart default
elif sudo virsh net-list --all | grep -q "default"; then
    echo "Default network is already running and autostarted."
else
    echo "No 'default' network found. You may need to create one manually."
fi

echo "=== KVM Setup Complete ==="
echo "Please log out and log back in to apply group changes."
echo "You can now use virsh to create virtual machines or run the virtual machine installation script."