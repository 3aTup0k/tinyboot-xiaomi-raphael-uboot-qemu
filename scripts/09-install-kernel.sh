#!/bin/bash
set -e

KERNEL_DEBS_DIR="${KERNEL_DEBS_DIR:-.}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09] 🧠 Installing kernel"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09]   └─ Kernel package directory: ${KERNEL_DEBS_DIR}"

mkdir -p rootdir/tmp
cp ${KERNEL_DEBS_DIR}/*-xiaomi-raphael.deb rootdir/tmp/

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09]   └─ Installing linux-image..."
chroot rootdir dpkg -i /tmp/linux-image-xiaomi-raphael.deb

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09]   └─ Installing linux-headers..."
chroot rootdir dpkg -i /tmp/linux-headers-xiaomi-raphael.deb

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09]   └─ Installing firmware..."
chroot rootdir dpkg -i /tmp/firmware-xiaomi-raphael.deb

rm -f rootdir/tmp/*-xiaomi-raphael.deb

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09]   └─ Updating initramfs..."
chroot rootdir update-initramfs -c -k all

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [09] ✅ Kernel installation completed"
