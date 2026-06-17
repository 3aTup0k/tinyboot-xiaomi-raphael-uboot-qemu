#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] 📦 Downloading pre-built iPod emulator for tinyfs-iphoneos"

if [[ "$SYSTEM_TYPE" != "tinyfs-iphoneos" ]]; then
    echo "Skipping emulator download for $SYSTEM_TYPE"
    exit 0
fi

# Create artifacts directory
mkdir -p build_artifacts/opt/ipod-emu

# Links to the latest release (n72ap_v1)
BOOTROM_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4"
NAND_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip"
NOR_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin"
# Binary is expected to be provided as a release asset or built separately
# For this workflow, we assume the binary qemu-system-arm is already in build_artifacts or downloaded from a release
BINARY_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/qemu-system-arm"

echo "Downloading assets..."
wget -O "build_artifacts/opt/ipod-emu/bootrom" "$BOOTROM_URL"
wget -O "build_artifacts/nand.zip" "$NAND_URL"
unzip -o "build_artifacts/nand.zip" -d "build_artifacts/opt/ipod-emu"
rm "build_artifacts/nand.zip"
wget -O "build_artifacts/opt/ipod-emu/nor" "$NOR_URL"

# Attempt to download the binary if it exists in the release
wget -O "build_artifacts/qemu-system-arm" "$BINARY_URL" || echo "Warning: Binary not found in release, ensuring it's handled by the emulator-build action"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] ✅ Emulator assets downloaded to build_artifacts/"
