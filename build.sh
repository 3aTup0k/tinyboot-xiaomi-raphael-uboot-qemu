#!/bin/bash
set -e


# Parse arguments
SYSTEM_TYPE="${1:?Please specify system type}"
KERNEL_VERSION="${2:-6.18}"
DESKTOP_ENV="${3:-phosh-full}"

# Parse distribution version arguments
if [[ "$SYSTEM_TYPE" == *"debian-"* ]]; then
    DEBIAN_VERSION="${DEBIAN_VERSION:?Please set DEBIAN_VERSION environment variable}"
    export DEBIAN_VERSION
elif [[ "$SYSTEM_TYPE" == *"ubuntu-"* ]]; then
    UBUNTU_VERSION="${UBUNTU_VERSION:?Please set UBUNTU_VERSION environment variable}"
    export UBUNTU_VERSION
elif [[ "$SYSTEM_TYPE" == *"kali-"* ]]; then
    DEBIAN_VERSION="${DEBIAN_VERSION:-kali-rolling}"
    export DEBIAN_VERSION
fi

# Parse build mode arguments
USE_DOCKER="${5:-false}"
export USE_DOCKER

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config file
. "$SCRIPT_DIR/config/build-config.sh"

# Load system configuration
TMP_SYSTEM_CONFIG=$(mktemp)
system_config "$SYSTEM_TYPE" "$DESKTOP_ENV" > "$TMP_SYSTEM_CONFIG"
while IFS= read -r line; do
    export "$line"
done < "$TMP_SYSTEM_CONFIG"
rm "$TMP_SYSTEM_CONFIG"

# Load mirror configuration
TMP_SOURCES_CONFIG=$(mktemp)
sources_config "$SYSTEM_TYPE" > "$TMP_SOURCES_CONFIG"
while IFS= read -r line; do
    export "$line"
done < "$TMP_SOURCES_CONFIG"
rm "$TMP_SOURCES_CONFIG"

# Export general variables
export SCRIPT_DIR
export KERNEL_VERSION
export DESKTOP_ENV
export IMAGE_NAME="rootfs.img"
export IMAGE_UUID="ee8d3593-59b1-480e-a3b6-4fefb17ee7d8"
export HOSTNAME="xiaomi-raphael"
export BOOT_IMG="xiaomi-k20pro-boot.img"
export KERNEL_DEBS_DIR="xiaomi-raphael-debs_$KERNEL_VERSION"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export DEBIAN_FRONTEND="noninteractive"
export SYSTEM_TYPE

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🎉"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] System Image Build Script"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🎉"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] System Type:      $SYSTEM_TYPE 🖥️"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Kernel Version:    $KERNEL_VERSION 🧠"
if [ -n "$DEBIAN_VERSION" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Debian Version:   $DEBIAN_VERSION 🐧"
elif [ -n "$UBUNTU_VERSION" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Ubuntu Version:   $UBUNTU_VERSION 🦁"
fi
if [[ "$SYSTEM_TYPE" == *"kali-"* ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Kali Version:     kali-rolling 🐉"
fi
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Image Size:       $IMAGE_SIZE 💾"
if [ "$IS_DESKTOP" = "true" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Desktop Env:       $DESKTOP_ENV 🎨"
fi
BOOTSTRAP_TOOL="${BOOTSTRAP_TOOL:-mmdebstrap}"
if [ "$BOOTSTRAP_TOOL" = "debootstrap" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Build Mode:       debootstrap 🛠️"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Build Mode:       mmdebstrap 📦"
fi
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🎉"

if [ ! -f "$BOOT_IMG" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ Error: $BOOT_IMG does not exist"
    exit 1
fi

if [ ! -d "$KERNEL_DEBS_DIR" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ Error: $KERNEL_DEBS_DIR directory does not exist"
    exit 1
fi

chmod +x "$SCRIPT_DIR/scripts"/*.sh

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🚀 Starting Build =========================================="
"$SCRIPT_DIR/scripts/00-build-emulator.sh"
"$SCRIPT_DIR/scripts/01-create-image.sh"
"$SCRIPT_DIR/scripts/02-bootstrap.sh"
"$SCRIPT_DIR/scripts/03-mount-dev.sh"
"$SCRIPT_DIR/scripts/04-config-network.sh"
"$SCRIPT_DIR/scripts/05-apt-setup.sh"
"$SCRIPT_DIR/scripts/06-install-all-packages.sh"
"$SCRIPT_DIR/scripts/07-config-locale.sh"
"$SCRIPT_DIR/scripts/08-add-screen-commands.sh"
"$SCRIPT_DIR/scripts/09-install-kernel.sh"
"$SCRIPT_DIR/scripts/10-config-ncm.sh"
"$SCRIPT_DIR/scripts/11-config-fstab.sh"
"$SCRIPT_DIR/scripts/12-create-users.sh"
"$SCRIPT_DIR/scripts/13-config-power.sh"
"$SCRIPT_DIR/scripts/14-config-zram.sh"
"$SCRIPT_DIR/scripts/15-cleanup.sh"
"$SCRIPT_DIR/scripts/17-install-emulator.sh"
"$SCRIPT_DIR/scripts/16-finalize.sh"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🎉 Build Finished 🎉 =========================================="

echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] 📦 Artifacts:"
ls -lh rootfs.img 2>/dev/null || true
ls -lh rootfs.7z 2>/dev/null || true
echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Build completed successfully!"
