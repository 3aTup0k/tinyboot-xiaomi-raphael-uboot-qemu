#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05] 📡 Updating apt sources and cache"

export DEBIAN_FRONTEND=noninteractive

cp rootdir/etc/apt/sources.list rootdir/etc/apt/sources.list.bak

if [[ "$SYSTEM_TYPE" == *"kali-"* ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05]   └─ Configuring Kali $DEBIAN_VERSION sources"
    cat > rootdir/etc/apt/sources.list << EOF
deb http://http.kali.org/kali/ $DEBIAN_VERSION main non-free contrib
EOF
elif [[ "$SYSTEM_TYPE" == *"ubuntu-"* ]]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05]   └─ Configuring Ubuntu $UBUNTU_VERSION sources"
    cat > rootdir/etc/apt/sources.list << EOF
deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-backports main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-security main restricted universe multiverse
EOF
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05]   └─ Configuring Debian $DEBIAN_VERSION sources"
    cat > rootdir/etc/apt/sources.list << EOF
deb [trusted=yes] http://deb.debian.org/debian/ $DEBIAN_VERSION main contrib non-free non-free-firmware
deb [trusted=yes] http://deb.debian.org/debian/ $DEBIAN_VERSION-updates main contrib non-free non-free-firmware
deb [trusted=yes] http://deb.debian.org/debian/ $DEBIAN_VERSION-backports main contrib non-free non-free-firmware
deb [trusted=yes] http://security.debian.org/debian-security $DEBIAN_VERSION-security main contrib non-free non-free-firmware
EOF
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05]   └─ Executing apt-get update..."
chroot rootdir apt-get -q update

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [05] ✅ apt configuration completed"
