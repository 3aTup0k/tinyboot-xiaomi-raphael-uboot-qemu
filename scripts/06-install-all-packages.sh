#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

. "$CONFIG_DIR/build-config.sh"

SYSTEM_TYPE="${SYSTEM_TYPE:-ubuntu-server}"
DESKTOP_ENV="${DESKTOP_ENV:-}"
DEBIAN_VERSION="${DEBIAN_VERSION:-trixie}"
UBUNTU_VERSION="${UBUNTU_VERSION:-resolute}"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06] 📦 Installing packages"

export DEBIAN_FRONTEND=noninteractive

# CRITICAL: Remove conflicting uutils package BEFORE any apt operations
echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Removing conflicting coreutils-from-uutils..."
chroot rootdir dpkg --purge --force-all coreutils-from-uutils 2>/dev/null || true

ALL_PACKAGES=$(get_packages "$SYSTEM_TYPE" "$DESKTOP_ENV")
DEVICE_PACKAGES="rmtfs protection-domain-mapper tqftpserv"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Base and Device packages: $(echo "$ALL_PACKAGES $DEVICE_PACKAGES" | tr ' ' ', ')"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Starting installation (this may take a few minutes...)"
# Fix broken dependencies first
chroot rootdir apt-get install -f -y
# Install main packages with force overwrite
chroot rootdir apt-get install -y -o Dpkg::Options::="--force-overwrite" $ALL_PACKAGES $DEVICE_PACKAGES
# Fix broken dependencies again after installation
chroot rootdir apt-get install -f -y


echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06] ✅ Package installation completed"


if [[ "$SYSTEM_TYPE" == *"debian-"* ]] || [[ "$SYSTEM_TYPE" == *"kali-"* ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Fixing Debian/Kali dpkg errors"
    chroot rootdir dpkg --remove --force-remove-reinstreq shim-signed 2>/dev/null || true
    chroot rootdir dpkg --purge shim-signed 2>/dev/null || true
    chroot rootdir dpkg --configure -a 2>/dev/null || true
    chroot rootdir apt-get -f install -y 2>/dev/null || true
fi

# Modify service configuration
if [[ "$SYSTEM_TYPE" == *"debian-"* ]] || [[ "$SYSTEM_TYPE" == *"kali-"* ]]; then
    sed -i '/ConditionKernelVersion/d' rootdir/lib/systemd/system/pd-mapper.service 2>/dev/null || true
fi

if [[ "$SYSTEM_TYPE" != *"server"* ]]; then
    if [ "$DESKTOP_ENV" = "gnome" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Configuring GDM auto-login"
        cat > rootdir/etc/gdm3/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=user
EOF
    elif [ "$DESKTOP_ENV" = "xfce" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Configuring LightDM auto-login"
        mkdir -p rootdir/etc/lightdm
        cat > rootdir/etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=user
autologin-user-timeout=0
EOF
        chroot rootdir systemctl enable lightdm
    elif [ "$DESKTOP_ENV" = "kde" ]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Configuring SDDM auto-login"
        mkdir -p rootdir/etc/sddm.conf.d
        cat > rootdir/etc/sddm.conf.d/autologin.conf << 'EOF'
[Autologin]
User=user
Session=plasma
EOF
        chroot rootdir systemctl enable sddm
    fi


fi

if [ -f "alsa-xiaomi-raphael.deb" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Installing ALSA configuration"
    cp alsa-xiaomi-raphael.deb rootdir/tmp/
    chroot rootdir dpkg -i /tmp/alsa-xiaomi-raphael.deb
    rm rootdir/tmp/alsa-xiaomi-raphael.deb
fi

if [[ "$SYSTEM_TYPE" != *"server"* ]]; then
    if [[ "$DESKTOP_ENV" == phosh* ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06]   └─ Enabling Phosh service"
        chroot rootdir systemctl enable phosh
    fi
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [06] ✅ Package installation completed"
