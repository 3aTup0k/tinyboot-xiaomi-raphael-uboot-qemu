#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# build.sh — Alpine + OpenRC RAM-based rootfs for Xiaomi Raphael
# Build: custom initramfs with squashfs + kernel from .deb
# Target: aarch64 (Xiaomi Redmi K20 Pro / sm8150-raphael)
# ============================================================

# ---- CONFIGURATION -----------------------------------------
KERNEL_VERSION="${KERNEL_VERSION:-7.0}"
ALPINE_VERSION="${ALPINE_VERSION:-latest-stable}"
OUTPUT="${OUTPUT:-$(pwd)/output}"
WORKDIR="${WORKDIR:-$(mktemp -d)}"
KEEP_WORKDIR="${KEEP_WORKDIR:-false}"
GH_MIRROR="${GH_MIRROR:-}"
BUILD_QEMU_IOS="${BUILD_QEMU_IOS:-false}"

# ---- PATHS -------------------------------------------------
ROOTFS="${WORKDIR}/rootfs"
INITRAMFS_DIR="${WORKDIR}/initramfs"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- ARCH DETECTION ----------------------------------------
BUILD_ARCH="$(uname -m)"
case "$BUILD_ARCH" in
    x86_64|amd64)  BUILD_ARCH="x86_64" ;;
    aarch64|arm64) BUILD_ARCH="aarch64" ;;
    *)
        echo "[!] Unsupported build architecture: ${BUILD_ARCH}"
        echo "    Supported: x86_64, aarch64"
        exit 1
        ;;
esac
echo "[*] Build host: ${BUILD_ARCH}"
echo "[*] Target:     aarch64 (Xiaomi Raphael)"
echo "[*] Alpine:     ${ALPINE_VERSION}"
echo "[*] Kernel:     v${KERNEL_VERSION}"

# ---- ALPINE REPOS ------------------------------------------
ALPINE_REPO="https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}"
ALPINE_MAIN="${ALPINE_REPO}/main"
ALPINE_COMMUNITY="${ALPINE_REPO}/community"
ALPINE_ARCH="aarch64"

# ---- KERNEL DEB URLS ---------------------------------------
GH_BASE="${GH_MIRROR}https://github.com"
KERNEL_BASE="${GH_BASE}/GengWei1997/kernel-deb/releases/download/kernel-v${KERNEL_VERSION}"
KERNEL_IMAGE_DEB="${KERNEL_BASE}/linux-image-xiaomi-raphael.deb"
KERNEL_FIRMWARE_DEB="${KERNEL_BASE}/firmware-xiaomi-raphael.deb"

# ---- PACKAGES ----------------------------------------------
PACKAGES="
  alpine-base
  busybox-static
  dropbear
"

# ---- QEMU runtime deps (for qemu-ios SDL display) --------
QEMU_RUNTIME_PACKAGES="
  sdl2
  sdl2-libsdl
  libglib
  pixman
  openssl
  libpng
  libjpeg-turbo
"

# ---- CLEANUP HANDLER ---------------------------------------
cleanup() {
    if [ "${KEEP_WORKDIR}" != "true" ] && [ -n "${WORKDIR}" ]; then
        rm -rf "${WORKDIR}"
    fi
}
trap cleanup EXIT

# ---- HELPER: log -------------------------------------------
log() { echo "[$(date +'%H:%M:%S')] $*"; }

# ---- QEMU-IOS BUILD (optional) -------------------------------
build_qemu_ios() {
    log "[qemu-ios] Building qemu-ios for aarch64/Alpine (via Docker)..."

    QEMU_BUILDER="${REPO_DIR}/build-qemu-ios.sh"
    if [ ! -f "${QEMU_BUILDER}" ]; then
        log "[qemu-ios] ✗ build-qemu-ios.sh not found!"
        exit 1
    fi

    chmod +x "${QEMU_BUILDER}"

    OUTPUT="${OUTPUT}" \
    KEEP_WORKDIR="true" \
    bash "${QEMU_BUILDER}"

    log "[qemu-ios] ✓ Build done"
}

install_qemu_ios() {
    log "[qemu-ios] Installing qemu-ios into rootfs..."

    QEMU_BIN_SRC="${OUTPUT}/qemu-system-arm"
    if [ ! -f "${QEMU_BIN_SRC}" ]; then
        log "[qemu-ios] ✗ qemu-system-arm binary not found in output/"
        log "[qemu-ios]   Expected: ${QEMU_BIN_SRC}"
        exit 1
    fi

    mkdir -p "${ROOTFS}/usr/bin"
    cp "${QEMU_BIN_SRC}" "${ROOTFS}/usr/bin/qemu-system-arm"
    log "    ✓ /usr/bin/qemu-system-arm ($(du -h "${ROOTFS}/usr/bin/qemu-system-arm" | cut -f1))"

    # Install QEMU runtime deps
    log "    Installing SDL/runtime libraries..."
    for pkg in ${QEMU_RUNTIME_PACKAGES}; do
        /tmp/apk.static --arch "${ALPINE_ARCH}" --root "${ROOTFS}" \
            --repository "${ALPINE_MAIN}" \
            --repository "${ALPINE_COMMUNITY}" \
            add --no-scripts "${pkg}" 2>/dev/null || true
    done

    # Create config directory for bootrom/NAND/NOR paths
    mkdir -p "${ROOTFS}/etc/qemu-ios"
    cat > "${ROOTFS}/etc/qemu-ios/env" <<-EOF
# qemu-ios configuration
# Edit these paths before running:
QEMU_IOS_BOOTROM="/mnt/userdata/qemu-ios/bootrom"
QEMU_IOS_NAND="/mnt/userdata/qemu-ios/nand"
QEMU_IOS_NOR="/mnt/userdata/qemu-ios/nor"
QEMU_IOS_EXTRAS="-serial mon:stdio -cpu max -m 2G -d unimp"
EOF

    log "    ✓ qemu-ios installed in rootfs"
}

# ---- STEP 1: Setup directories -----------------------------
setup_dirs() {
    log "[1/9] Creating working directories..."
    mkdir -p "${ROOTFS}" "${INITRAMFS_DIR}" "${OUTPUT}"
}

# ---- STEP 2: Download apk-tools-static ----------------------
download_apk() {
    log "[2/9] Downloading apk-tools-static (${BUILD_ARCH})..."

    # Resolve the latest apk-tools-static version from Alpine APKINDEX
    ALPINE_MAIN_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/${BUILD_ARCH}"
    APKINDEX_URL="${ALPINE_MAIN_URL}/APKINDEX.tar.gz"

    APK_TOOLS_VER=$(curl -fsSL "${APKINDEX_URL}" \
        | tar -xz -O APKINDEX 2>/dev/null \
        | grep -A10 'P:apk-tools-static' \
        | grep '^V:' | cut -d: -f2 | head -1)

    if [ -z "${APK_TOOLS_VER}" ]; then
        APK_TOOLS_VER="2.14.6-r0"
    fi

    APK_URL="${ALPINE_MAIN_URL}/apk-tools-static-${APK_TOOLS_VER}.apk"

    log "    apk-tools: ${APK_TOOLS_VER}, arch: ${BUILD_ARCH}"
    curl -fsSL -o /tmp/apk-tools.apk "${APK_URL}"

    # apk is a tar.gz; extract apk.static from it
    mkdir -p /tmp/apk-extract
    tar -xzf /tmp/apk-tools.apk -C /tmp/apk-extract
    cp /tmp/apk-extract/sbin/apk.static /tmp/apk.static
    chmod +x /tmp/apk.static
    rm -rf /tmp/apk-extract /tmp/apk-tools.apk

    log "    ✓ apk.static ready ($(/tmp/apk.static --version 2>&1 | head -1))"
}

# ---- STEP 3: Build Alpine rootfs ----------------------------
build_rootfs() {
    log "[3/9] Bootstrapping Alpine Linux rootfs (aarch64)..."

    mkdir -p "${ROOTFS}/etc/apk"

    # Write repositories
    cat > "${ROOTFS}/etc/apk/repositories" <<-REPOS
${ALPINE_MAIN}
${ALPINE_COMMUNITY}
REPOS

    # Initialize APK database
    /tmp/apk.static --arch "${ALPINE_ARCH}" --root "${ROOTFS}" --initdb add --no-scripts

    # Install packages
    for pkg in ${PACKAGES}; do
        log "    Installing: ${pkg}"
        /tmp/apk.static --arch "${ALPINE_ARCH}" --root "${ROOTFS}" \
            --repository "${ALPINE_MAIN}" \
            --repository "${ALPINE_COMMUNITY}" \
            add --no-scripts "${pkg}"
    done

    # Update package index in rootfs
    /tmp/apk.static --arch "${ALPINE_ARCH}" --root "${ROOTFS}" \
        --cache-dir "${ROOTFS}/var/cache/apk" upgrade --no-scripts 2>/dev/null || true

    # Clean apk cache
    rm -rf "${ROOTFS}/var/cache/apk"/*
}

# ---- STEP 4: Configure rootfs -------------------------------
configure_rootfs() {
    log "[4/9] Configuring Alpine rootfs..."

    # --- hostname ---
    echo "alpine-raphael" > "${ROOTFS}/etc/hostname"

    # --- hosts ---
    cat > "${ROOTFS}/etc/hosts" <<-EOF
127.0.0.1       localhost
::1             localhost
127.0.0.1       alpine-raphael
EOF

    # --- inittab ---
    cat > "${ROOTFS}/etc/inittab" <<-'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown

tty1::respawn:/sbin/getty -L 0 tty1 vt100
ttyMSM0::respawn:/sbin/getty -L 115200 ttyMSM0 vt100
EOF

    # --- fstab ---
    cat > "${ROOTFS}/etc/fstab" <<-EOF
/dev/disk/by-partlabel/userdata / ext4 defaults 0 1
/dev/disk/by-partlabel/cache    /boot vfat defaults 0 0
tmpfs                           /tmp  tmpfs defaults 0 0
EOF

    # --- networking: bring up loopback ---
    mkdir -p "${ROOTFS}/etc/network"
    cat > "${ROOTFS}/etc/network/interfaces" <<-EOF
auto lo
iface lo inet loopback
EOF

    # --- root password (empty from console) ---
    sed -i 's/^root:.*/root:!:0:99999:7:::/' "${ROOTFS}/etc/shadow" 2>/dev/null || true

    # --- dropbear config (optional, no network needed) ---
    mkdir -p "${ROOTFS}/etc/dropbear"
    cat > "${ROOTFS}/etc/conf.d/dropbear" <<-EOF
rc_need=""
EOF

    # --- /boot directory ---
    mkdir -p "${ROOTFS}/boot"
    # -- mdev -- 
    mkdir -p "${ROOTFS}/etc/mdev"

    # --- copy overlay files ---
    if [ -d "${REPO_DIR}/overlays" ]; then
        log "    Applying overlay files..."
        cp -r "${REPO_DIR}/overlays/"* "${ROOTFS}/" 2>/dev/null || true
    fi

    # --- set runlevels for openrc ---
    # We can't run rc-update (needs chroot), so we create symlinks manually
    mkdir -p "${ROOTFS}/etc/runlevels"/{sysinit,boot,default,shutdown}

    # sysinit
    ln -sf /etc/init.d/sysinit    "${ROOTFS}/etc/runlevels/sysinit/sysinit" 2>/dev/null || true
    ln -sf /etc/init.d/mdev       "${ROOTFS}/etc/runlevels/sysinit/mdev" 2>/dev/null || true

    # boot
    for svc in hostname bootmisc syslog swap; do
        ln -sf "/etc/init.d/${svc}" "${ROOTFS}/etc/runlevels/boot/${svc}" 2>/dev/null || true
    done

    # default
    for svc in dropbear qemu-ios; do
        if [ -f "${ROOTFS}/etc/init.d/${svc}" ]; then
            ln -sf "/etc/init.d/${svc}" "${ROOTFS}/etc/runlevels/default/${svc}" 2>/dev/null || true
        fi
    done

    # Ensure essential device nodes
    mkdir -p "${ROOTFS}/dev"
    [ -e "${ROOTFS}/dev/console" ]   || mknod -m 600 "${ROOTFS}/dev/console"   c 5 1 2>/dev/null || true
    [ -e "${ROOTFS}/dev/null" ]      || mknod -m 666 "${ROOTFS}/dev/null"      c 1 3 2>/dev/null || true
    [ -e "${ROOTFS}/dev/zero" ]      || mknod -m 666 "${ROOTFS}/dev/zero"      c 1 5 2>/dev/null || true
    [ -e "${ROOTFS}/dev/random" ]    || mknod -m 444 "${ROOTFS}/dev/random"    c 1 8 2>/dev/null || true
    [ -e "${ROOTFS}/dev/urandom" ]   || mknod -m 444 "${ROOTFS}/dev/urandom"   c 1 9 2>/dev/null || true
    [ -e "${ROOTFS}/dev/tty" ]       || mknod -m 666 "${ROOTFS}/dev/tty"       c 5 0 2>/dev/null || true
}

# ---- STEP 5: Download and extract kernel --------------------
download_kernel() {
    log "[5/9] Downloading kernel packages (v${KERNEL_VERSION})..."

    curl -fsSL -o "${WORKDIR}/linux-image-xiaomi-raphael.deb" "${KERNEL_IMAGE_DEB}"
    log "    ✓ linux-image-xiaomi-raphael.deb"

    curl -fsSL -o "${WORKDIR}/firmware-xiaomi-raphael.deb" "${KERNEL_FIRMWARE_DEB}" || {
        log "    ⚠ firmware package not found, skipping"
        touch "${WORKDIR}/firmware-xiaomi-raphael.deb"
    }
}

extract_kernel() {
    log "[6/9] Extracting kernel + modules..."

    mkdir -p "${WORKDIR}/kernel-extract"
    (
        cd "${WORKDIR}/kernel-extract"

        ar x "${WORKDIR}/linux-image-xiaomi-raphael.deb"
        if [ -f data.tar.xz ]; then
            tar xf data.tar.xz
        elif [ -f data.tar.zst ]; then
            tar xf data.tar.zst
        elif [ -f data.tar.gz ]; then
            tar xf data.tar.gz
        else
            log "[!] Unknown data archive format in .deb"
            ls -la
            exit 1
        fi
    )

    # Find kernel version from extracted files
    KERNEL_RELEASE=$(ls "${WORKDIR}/kernel-extract/lib/modules/" 2>/dev/null | head -1 || true)
    if [ -z "${KERNEL_RELEASE}" ]; then
        log "[!] No kernel modules found!"
        exit 1
    fi
    log "    Kernel release: ${KERNEL_RELEASE}"

    # Copy kernel (vmlinuz)
    VMLINUZ=$(find "${WORKDIR}/kernel-extract/boot" -name "vmlinuz-*" 2>/dev/null | head -1 || true)
    if [ -n "${VMLINUZ}" ]; then
        cp "${VMLINUZ}" "${OUTPUT}/linux.efi"
        log "    ✓ Kernel: ${OUTPUT}/linux.efi"
    else
        log "[!] vmlinuz not found in kernel package!"
        exit 1
    fi

    # Copy kernel modules to rootfs
    if [ -d "${WORKDIR}/kernel-extract/lib/modules/${KERNEL_RELEASE}" ]; then
        mkdir -p "${ROOTFS}/lib/modules"
        cp -r "${WORKDIR}/kernel-extract/lib/modules/${KERNEL_RELEASE}" \
              "${ROOTFS}/lib/modules/${KERNEL_RELEASE}"
        log "    ✓ Kernel modules: ${KERNEL_RELEASE}"

        # Run depmod for the modules
        if command -v depmod &>/dev/null; then
            depmod -b "${ROOTFS}" "${KERNEL_RELEASE}" 2>/dev/null || true
        fi
    fi

    # Copy DTBs
    DTB_DIR=$(find "${WORKDIR}/kernel-extract/usr/lib" -type d -name "dtb*" 2>/dev/null | head -1 || true)
    if [ -z "${DTB_DIR}" ]; then
        DTB_DIR=$(find "${WORKDIR}/kernel-extract" -type d -name "dtbs" 2>/dev/null | head -1 || true)
    fi
    if [ -n "${DTB_DIR}" ] && [ -d "${DTB_DIR}" ]; then
        cp -r "${DTB_DIR}" "${OUTPUT}/dtbs" 2>/dev/null || true
        log "    ✓ Device tree blobs"
    fi

    # Extract firmware
    if [ -f "${WORKDIR}/firmware-xiaomi-raphael.deb" ]; then
        mkdir -p "${WORKDIR}/firmware-extract"
        (
            cd "${WORKDIR}/firmware-extract"
            ar x "${WORKDIR}/firmware-xiaomi-raphael.deb" 2>/dev/null
            if ls data.tar.* 2>/dev/null; then
                for f in data.tar.*; do
                    tar xf "$f" 2>/dev/null || true
                done
            fi
        )
        if [ -d "${WORKDIR}/firmware-extract/lib/firmware" ]; then
            mkdir -p "${ROOTFS}/lib/firmware"
            cp -r "${WORKDIR}/firmware-extract/lib/firmware/"* "${ROOTFS}/lib/firmware/" 2>/dev/null || true
            log "    ✓ Firmware files"
        fi
    fi
}

# ---- STEP 7: Create squashfs of Alpine rootfs ---------------
create_squashfs() {
    log "[7/9] Creating squashfs of Alpine rootfs..."

    if ! command -v mksquashfs &>/dev/null; then
        log "[!] mksquashfs not found. Installing squashfs-tools..."
        if command -v apt-get &>/dev/null; then
            apt-get update -qq && apt-get install -y -qq squashfs-tools
        elif command -v apk &>/dev/null; then
            apk add squashfs-tools
        else
            log "[!] Cannot install squashfs-tools. Install manually."
            exit 1
        fi
    fi

    mksquashfs "${ROOTFS}" "${WORKDIR}/rootfs.squashfs" \
        -comp xz -b 256K -Xbcj arm -noappend
    log "    ✓ rootfs.squashfs ($(du -h "${WORKDIR}/rootfs.squashfs" | cut -f1))"
}

# ---- STEP 8: Build initramfs --------------------------------
build_initramfs() {
    log "[8/9] Building initramfs..."

    rm -rf "${INITRAMFS_DIR}"
    mkdir -p "${INITRAMFS_DIR}/bin"

    # Copy busybox.static
    BUSYBOX_STATIC=$(find "${ROOTFS}" -name "busybox.static" 2>/dev/null | head -1)
    if [ -z "${BUSYBOX_STATIC}" ]; then
        # Try to get it from the apk cache or rootfs
        BUSYBOX_STATIC=$(find "${WORKDIR}" -name "busybox.static" 2>/dev/null | head -1)
    fi
    if [ -z "${BUSYBOX_STATIC}" ]; then
        # Extract busybox-static from the installed packages
        for pkgdir in "${ROOTFS}/var/db/apk"/*/; do
            if grep -q "busybox-static" "${pkgdir}/packages" 2>/dev/null; then
                # installed package info
                break
            fi
        done
        # Fallback: use busybox from rootfs (dynamically linked)
        BUSYBOX_STATIC="${ROOTFS}/bin/busybox"
    fi

    if [ -n "${BUSYBOX_STATIC}" ]; then
        cp "${BUSYBOX_STATIC}" "${INITRAMFS_DIR}/bin/busybox"
        log "    ✓ busybox ($(du -h "${INITRAMFS_DIR}/bin/busybox" | cut -f1))"
    else
        log "[!] No busybox binary found!"
        exit 1
    fi

    # Copy init script
    cp "${REPO_DIR}/initramfs/init" "${INITRAMFS_DIR}/init"
    chmod +x "${INITRAMFS_DIR}/init"

    # Copy squashfs
    cp "${WORKDIR}/rootfs.squashfs" "${INITRAMFS_DIR}/rootfs.squashfs"

    # Create cpio archive
    (
        cd "${INITRAMFS_DIR}"
        find . | cpio -H newc -o | gzip -9 > "${WORKDIR}/initramfs.cpio.gz"
    )

    cp "${WORKDIR}/initramfs.cpio.gz" "${OUTPUT}/initramfs"
    log "    ✓ initramfs ($(du -h "${OUTPUT}/initramfs" | cut -f1))"
}

# ---- STEP 8b: Create FAT32 boot image (optional) ------------
create_bootimg() {
    if ! command -v mkfs.fat &>/dev/null || ! command -v mcopy &>/dev/null; then
        log "    Skipping boot.img (install dosfstools + mtools)"
        return
    fi

    log "[8b] Creating boot.img (FAT32)..."
    local BOOT_IMG="${OUTPUT}/boot.img"

    rm -f "${BOOT_IMG}"
    mkfs.fat -C "${BOOT_IMG}" 256M >/dev/null 2>&1

    mcopy -i "${BOOT_IMG}" "${OUTPUT}/linux.efi" ::/linux.efi
    mcopy -i "${BOOT_IMG}" "${OUTPUT}/initramfs" ::/initramfs

    if [ -d "${OUTPUT}/dtbs" ]; then
        mcopy -i "${BOOT_IMG}" -s "${OUTPUT}/dtbs" ::/dtbs
    fi

    log "    ✓ boot.img ($(du -h "${BOOT_IMG}" | cut -f1))"
}

# ---- STEP 9: Verify and print summary -----------------------
verify_output() {
    log "[9/9] Verifying output..."

    echo ""
    echo "============================================"
    echo "  Build Complete - Xiaomi Raphael Alpine RAM"
    echo "============================================"
    echo ""

    ls -lh "${OUTPUT}/linux.efi" 2>/dev/null && echo "  Kernel"
    ls -lh "${OUTPUT}/initramfs" 2>/dev/null && echo "  Initramfs"
    if [ -f "${OUTPUT}/qemu-system-arm" ]; then
        echo "  qemu-ios (for Alpine): ${OUTPUT}/qemu-system-arm"
        ls -lh "${OUTPUT}/qemu-system-arm"
    fi
    if [ -d "${OUTPUT}/dtbs" ]; then
        echo "  Device tree blobs: ${OUTPUT}/dtbs/"
        ls -lh "${OUTPUT}/dtbs/"
    fi

    echo ""
    echo "--- Size Verification ---"
    TOTAL=0
    if [ -f "${OUTPUT}/linux.efi" ]; then
        KERNEL_SIZE=$(stat -c%s "${OUTPUT}/linux.efi" 2>/dev/null || stat -f%z "${OUTPUT}/linux.efi" 2>/dev/null)
        TOTAL=$((TOTAL + KERNEL_SIZE))
        echo "  linux.efi:  $(numfmt --to=iec "${KERNEL_SIZE}" 2>/dev/null || echo "${KERNEL_SIZE} bytes")"
    fi
    if [ -f "${OUTPUT}/initramfs" ]; then
        INITRAMFS_SIZE=$(stat -c%s "${OUTPUT}/initramfs" 2>/dev/null || stat -f%z "${OUTPUT}/initramfs" 2>/dev/null)
        TOTAL=$((TOTAL + INITRAMFS_SIZE))
        echo "  initramfs:  $(numfmt --to=iec "${INITRAMFS_SIZE}" 2>/dev/null || echo "${INITRAMFS_SIZE} bytes")"
    fi
    echo "  ----------------------------"
    echo "  TOTAL:      $(numfmt --to=iec "${TOTAL}" 2>/dev/null || echo "${TOTAL} bytes")"
    echo "  Cache limit: 256 MB"
    if [ "${TOTAL}" -lt 268435456 ]; then
        echo "  ✓ Fits in cache partition!"
    else
        echo "  ✗ EXCEEDS 256 MB limit! Reduce rootfs size."
    fi
    echo ""

    echo "--- Flashing Instructions ---"
    echo "  1. Enter fastboot mode on your phone"
    echo "  2. fastboot flash boot u-boot.img  (do this once)"
    echo "  3. fastboot flash cache boot.img  (kernel + initramfs)"
    echo "  4. fastboot reboot"
    echo ""
    echo "  To create boot.img manually:"
    echo "    mkfs.fat -C boot.img 256M"
    echo "    mcopy -i boot.img output/linux.efi ::/linux.efi"
    echo "    mcopy -i boot.img output/initramfs ::/initramfs"
    echo "    mcopy -i boot.img -s output/dtbs ::/dtbs"
    echo ""
    echo "--- Output files ---"
    echo "  ${OUTPUT}/"
    ls -lh "${OUTPUT}/"
}

# ---- MAIN ---------------------------------------------------
main() {
    echo ""
    echo "============================================"
    echo "  Alpine RAM Rootfs Builder for Xiaomi Raphael"
    echo "============================================"
    if [ "${BUILD_QEMU_IOS}" = "true" ]; then
        echo "  QEMU-iOS:  ENABLED (iPod Touch 2G emulator)"
    else
        echo "  QEMU-iOS:  disabled (set BUILD_QEMU_IOS=true)"
    fi
    echo ""

    setup_dirs
    download_apk
    build_rootfs

    if [ "${BUILD_QEMU_IOS}" = "true" ]; then
        build_qemu_ios
    fi

    configure_rootfs

    if [ "${BUILD_QEMU_IOS}" = "true" ]; then
        install_qemu_ios
    fi

    download_kernel
    extract_kernel
    create_squashfs
    build_initramfs
    create_bootimg
    verify_output

    if [ "${KEEP_WORKDIR}" != "true" ]; then
        log "Cleaning up..."
        rm -rf "${WORKDIR}"
    fi

    log "Done! Output in: ${OUTPUT}/"
}

main "$@"
