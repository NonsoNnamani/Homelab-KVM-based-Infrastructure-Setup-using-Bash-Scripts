#cloud-config
hostname: ${HOSTNAME}
manage_etc_hosts: true

users:
  - name: ${NAME}
    gecos: ${NAME} is the admin user for this machine and has sudo privileges.
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    # Hashed version of password to login to admin user
    chpasswd:
      list: |
        "${NAME}:${PASSWORD_HASH}"
      expire: false
    lock_passwd: false
    ssh_authorized_keys:
      - ${SSH_KEY}

ssh_pwauth: true
disable_root: true

package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - vim
  - net-tools
  - ca-certificates
  - apt-transport-https
  - software-properties-common
  - python3
  - python3-pip
  - python3-venv
  - git

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1

runcmd:
  # Disable swap for Kubernetes
  - sed -i '/ swap / s/^/#/' /etc/fstab
  - swapoff -a

  # Load kernel modules
  - modprobe overlay
  - modprobe br_netfilter

  # Apply sysctl settings
  - sysctl --system

  # Add and install official Ansible package
  - add-apt-repository --yes --update ppa:ansible/ansible
  - apt-get install -y ansible

  # Install Network Manager for better network management
  - apt-get install -y network-manager
  - |
    MAC=$(nmcli device show enp1s0 | grep HWADDR | awk '{print $2}')
    cat > /etc/netplan/01-cloud-init.yaml <<'EOF'
    network:
      version: 2
      ethernets:
        enp1s0:
          match:
            macaddress: "${MAC}"
          set-name: "enp1s0"
          dhcp4: false
          addresses:
            - ${ADDRESS_CIDR}
          gateway4: ${GATEWAY4}
          nameservers:
            addresses: [1.1.1.1, 8.8.8.8]
    EOF
  - netplan generate
  - netplan apply

  # Optional: install containerd prerequisites
  - mkdir -p /etc/containerd
  - apt-get install -y containerd
  - containerd config default > /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd

final_message: |
  Cloud-init completed successfully!
  System is ready for Kubernetes bootstrap.
  IP Address: ${ADDRESS_CIDR}
  Hostname: ${HOSTNAME}
