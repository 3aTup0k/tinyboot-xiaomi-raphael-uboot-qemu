#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] 📱 Building iPod emulator on host for tinyfs-iphoneos"

if [[ "$SYSTEM_TYPE" != "tinyfs-iphoneos" ]]; then
    echo "Skipping emulator build for $SYSTEM_TYPE"
    exit 0
fi

# Install build dependencies on the host
sudo apt-get update
sudo apt-get install -y git build-essential pkg-config libssl-dev libsdl2-dev libpixman-1-dev libglib2.0-dev ninja-build python3 unzip wget

# Create artifacts directory
mkdir -p build_artifacts

# 1. Build the binary
git clone https://github.com/devos50/qemu-ios.git qemu-ios-src
cd qemu-ios-src
mkdir build && cd build

../configure --target-list=arm-softmmu \
    --enable-sdl \
    --disable-cocoa \
    --disable-capstone \
    --disable-slirp \
    --disable-guest-agent \
    --disable-werror \
    --extra-cflags="-fPIC" \
    --extra-ldflags="-lcrypto"
 \
    --extra-ldflags="-lcrypto"

make -j$(nproc)

# Save binary to artifacts
echo "Saving emulator binary to build_artifacts..."
cp arm-softmmu/qemu-system-arm ../../build_artifacts/qemu-system-arm
cd ../..
rm -rf qemu-ios-src

# 2. Download and prepare assets
echo "Downloading emulator assets to build_artifacts..."
mkdir -p build_artifacts/opt/ipod-emu

# Links
BOOTROM_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/bootrom_240_4"
NAND_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nand_n72ap.zip"
NOR_URL="https://github.com/devos50/qemu-ios/releases/download/n72ap_v1/nor_n72ap.bin"

# Download Bootrom
wget -O "build_artifacts/opt/ipod-emu/bootrom" "$BOOTROM_URL"

# Download and Extract NAND
wget -O "build_artifacts/nand.zip" "$NAND_URL"
unzip -o "build_artifacts/nand.zip" -d "build_artifacts/opt/ipod-emu"
rm "build_artifacts/nand.zip"

# Download NOR
wget -O "build_artifacts/opt/ipod-emu/nor" "$NOR_URL"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [00] ✅ Emulator and assets built on host and saved to build_artifacts/"
