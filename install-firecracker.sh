#!/bin/bash
set -euo pipefail

# Exit if not run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Install dependencies
# apt-get update
apt-get install -y make git gcc bridge-utils net-tools libelf-dev pkg-config \
  debootstrap apt-transport-https lsof screen

# Install Firecracker
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest=$(basename $(curl -fsSLI -o /dev/null -w %{url_effective} $release_url/latest))
arch=$(uname -m)
echo step1
curl -LO $release_url/download/${latest}/firecracker-${latest}-${arch}.tgz
echo step2
tar -xzf firecracker-${latest}-${arch}.tgz
echo step3
mv release-${latest}-${arch}/firecracker-${latest}-${arch} /usr/local/bin/firecracker
echo step4
rm -rf firecracker-*.tgz release-*
echo step5
# Create workspace
mkdir -p /opt/firecracker/{vms,kernel,rootfs,snapshots}
cd /opt/firecracker
echo step6

# Download kernel
latest=$(wget "http://spec.ccfc.min.s3.amazonaws.com/?prefix=firecracker-ci/v1.9/aarch64/vmlinux-5.10&list-type=2" -O - 2>/dev/null | grep "(?<=<Key>)(firecracker-ci/v1.9/aarch64/vmlinux-5\.10\.[0-9]{3})(?=</Key>)" -o -P)
echo step7
kernel_url=https://s3.amazonaws.com/spec.ccfc.min/${latest}
curl -fsSL -o kernel/vmlinux $kernel_url
echo step8
chmod +x kernel/vmlinux
echo step9

# Create rootfs (100MB)
rootfs_path="rootfs/rootfs.ext4"
dd if=/dev/zero of=$rootfs_path bs=1M count=100
mkfs.ext4 $rootfs_path

# Mount and install Ubuntu
mkdir -p /mnt/rootfs
mount -o loop $rootfs_path /mnt/rootfs
debootstrap --arch=amd64 focal /mnt/rootfs
umount /mnt/rootfs

# Set up networking
ip link add name br0 type bridge
ip addr add 172.16.0.1/24 dev br0
ip link set br0 up

iptables -t nat -A POSTROUTING -o $(ip route get 1 | awk '{print $5}') -j MASQUERADE
iptables -A FORWARD -i br0 -o $(ip route get 1 | awk '{print $5}') -j ACCEPT
sysctl -w net.ipv4.ip_forward=1