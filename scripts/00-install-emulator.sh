#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] 📦 Downloading QEMU-iOS and assets for tinyboot-iphoneos"

if [[ "$SYSTEM_TYPE" != "tinyboot-iphoneos" ]]; then
    echo "Skipping emulator installation for $SYSTEM_TYPE"
    exit 0
fi

# Create artifacts directory
mkdir -p build_artifacts/opt/ipod-emu

# Links
BINARY_URL="https://github.com/3aTup0k/tinyboot-xiaomi-raphael-uboot-qemu/releases/download/build-qemu-arm64/qemu-system-arm"
BOOTROM_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4"
NAND_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip"
NOR_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin"

echo "Downloading emulator binary..."
wget -O "build_artifacts/qemu-system-arm" "$BINARY_URL"

echo "Downloading assets..."
wget -O "build_artifacts/opt/ipod-emu/bootrom" "$BOOTROM_URL"
wget -O "build_artifacts/nand.zip" "$NAND_URL"
# Unzip directly into /opt/ipod-emu; as NAND zip contains 'nand/' folder, it creates /opt/ipod-emu/nand/
unzip -o "build_artifacts/nand.zip" -d "build_artifacts/opt/ipod-emu"
rm "build_artifacts/nand.zip"
wget -O "build_artifacts/opt/ipod-emu/nor" "$NOR_URL"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] ✅ Emulator and assets ready in build_artifacts/"
