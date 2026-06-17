#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] 📦 Downloading pre-built iPod emulator for tinyfs-iphoneos"

if [[ "$SYSTEM_TYPE" != "tinyfs-iphoneos" ]]; then
    echo "Skipping emulator download for $SYSTEM_TYPE"
    exit 0
fi

# Create artifacts directory
mkdir -p build_artifacts/opt/ipod-emu

# Links
# Binary is downloaded from our own repository's release v1.1
BINARY_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/v1.1/qemu-system-arm"
BOOTROM_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4"
NAND_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip"
NOR_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin"

# Download Binary
echo "Downloading emulator binary from our release..."
wget -O "build_artifacts/qemu-system-arm" "$BINARY_URL" || echo "Warning: Could not download binary from release, check if latest-qemu-arm exists"

# Download Bootrom
wget -O "build_artifacts/opt/ipod-emu/bootrom" "$BOOTROM_URL"

# Download and Extract NAND
wget -O "build_artifacts/nand.zip" "$NAND_URL"
unzip -o "build_artifacts/nand.zip" -d "build_artifacts/opt/ipod-emu"
rm "build_artifacts/nand.zip"

# Download NOR
wget -O "build_artifacts/opt/ipod-emu/nor" "$NOR_URL"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] ✅ Emulator assets downloaded to build_artifacts/"
