#!/bin/bash

cd /opt/firecracker/rootfs
# Download Alpine minirootfs (x86_64)
wget https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz
# Create a 64MB image file
dd if=/dev/zero of=rootfs.ext4 bs=1M count=64
# Format as ext4
mkfs.ext4 rootfs.ext4
mkdir -p /mnt/alpine-root
mount -o loop rootfs.ext4 /mnt/alpine-root
# Extract Alpine rootfs into it
tar -xzf alpine-minirootfs-3.19.1-x86_64.tar.gz -C /mnt/alpine-root
bash -c 'echo -e "#!/bin/sh\necho \"🔥 Init working\"\nexec /bin/sh" > /mnt/alpine-root/init'
sudo chmod +x /mnt/alpine-root/init
umount /mnt/alpine-root

rm /opt/firecracker/rootfs/rootfs.ext4
# Mount and install Ubuntu
mkdir -p /tmp/alpine-rootfs
cd /tmp/alpine-rootfs
# Download Alpine minirootfs
wget https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.4-x86_64.tar.gz
# Extract it
mkdir rootfs
tar -xf alpine-minirootfs-*.tar.gz -C rootfs
dd if=/dev/zero of=rootfs.ext4 bs=1M count=64
mkfs.ext4 rootfs.ext4
mkdir /mnt/tmpfs
mount -o loop rootfs.ext4 /mnt/tmpfs
cp -a rootfs/* /mnt/tmpfs
umount /mnt/tmpfs
echo -e '#!/bin/sh\necho "Hello from init"\nexec /bin/sh' | tee rootfs/root/init
chmod +x rootfs/root/init
mount -o loop rootfs.ext4 /mnt/tmpfs
cp rootfs/root/init /mnt/tmpfs/root/init
umount /mnt/tmpfs
mv /tmp/alpine-rootfs/rootfs.ext4 /opt/firecracker/rootfs/rootfs.ext4
chmod 644 /opt/firecracker/rootfs/rootfs.ext4

# Set up networking
ip link add name br0 type bridge
ip addr add 172.16.0.1/24 dev br0
ip link set br0 up

iptables -t nat -A POSTROUTING -o $(ip route get 1 | awk '{print $5}') -j MASQUERADE
iptables -A FORWARD -i br0 -o $(ip route get 1 | awk '{print $5}') -j ACCEPT
sysctl -w net.ipv4.ip_forward=1
