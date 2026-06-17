#!/bin/bash
set -e

# Parse arguments
SYSTEM_TYPE="${1:-tinyboot-iphoneos}"
KERNEL_VERSION="${2:-6.18}"
DESKTOP_ENV="${3:-}"

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

# General variables
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

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🚀 Starting Build: $SYSTEM_TYPE =========================================="

# Step 0: Download Emulator and Assets
"$SCRIPT_DIR/scripts/00-install-emulator.sh"

# Step 1-15: Standard RootFS Build (Original debian-server flow)
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

# Step 17: Install and configure emulator for autostart
"$SCRIPT_DIR/scripts/17-finalize-emulator.sh"

# Step 16: Finalize image
"$SCRIPT_DIR/scripts/16-finalize.sh"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ========================================== 🎉 Build Finished 🎉 =========================================="
