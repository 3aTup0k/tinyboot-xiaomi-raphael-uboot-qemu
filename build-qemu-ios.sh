#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# build-qemu-ios.sh
# Build qemu-ios (iPod Touch 2G) for aarch64/Alpine Linux
# Uses Docker + multiarch/qemu-user-static for cross-build
# Builds inside arm64v8/alpine for musl libc compatibility
# ============================================================

QEMU_IOS_REPO="${QEMU_IOS_REPO:-https://github.com/devos50/qemu-ios.git}"
QEMU_IOS_BRANCH="${QEMU_IOS_BRANCH:-ipod_touch_2g}"
OUTPUT="${OUTPUT:-$(pwd)/output}"
WORKDIR="${WORKDIR:-$(mktemp -d)}"
KEEP_WORKDIR="${KEEP_WORKDIR:-false}"

cleanup() {
    if [ "${KEEP_WORKDIR}" != "true" ] && [ -n "${WORKDIR}" ]; then
        rm -rf "${WORKDIR}"
    fi
}
trap cleanup EXIT

log() { echo "[$(date +'%H:%M:%S')] $*"; }

build_qemu_ios() {
    log "[qemu-ios] Building for aarch64/Alpine (musl)..."
    log "[qemu-ios] Repo: ${QEMU_IOS_REPO} (branch: ${QEMU_IOS_BRANCH})"

    mkdir -p "${OUTPUT}"

    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true

    docker run --rm -v "${WORKDIR}:/build" arm64v8/alpine:3.21 sh -c '
        set -euo pipefail

        echo "[docker] Installing build dependencies..."
        apk add --no-cache \
            alpine-sdk git ninja-build linux-headers \
            sdl2-dev pixman-dev glib-dev openssl-dev \
            python3 py3-setuptools

        echo "[docker] Cloning qemu-ios..."
        git clone --depth=1 --branch="'"${QEMU_IOS_BRANCH}"'" \
            "'"${QEMU_IOS_REPO}"'" /build/qemu-ios

        cd /build/qemu-ios
        mkdir -p build && cd build

        echo "[docker] Configuring QEMU..."
        ../configure \
            --enable-sdl \
            --disable-cocoa \
            --target-list=arm-softmmu \
            --disable-capstone \
            --disable-slirp \
            --extra-cflags=-I/usr/include/openssl \
            --extra-ldflags=-lcrypto \
            --disable-werror \
            --enable-pie \
            --prefix=/usr

        echo "[docker] Building (using all cores)..."
        make -j$(nproc)

        echo "[docker] Build complete!"
    '

    QEMU_BINARY="${WORKDIR}/qemu-ios/build/arm-softmmu/qemu-system-arm"
    if [ -f "${QEMU_BINARY}" ]; then
        cp "${QEMU_BINARY}" "${OUTPUT}/qemu-system-arm"
        log "[qemu-ios] ✓ Binary: ${OUTPUT}/qemu-system-arm"
        log "[qemu-ios]   Size: $(du -h "${OUTPUT}/qemu-system-arm" | cut -f1)"
        log "[qemu-ios]   Linked against: $(file "${OUTPUT}/qemu-system-arm" | grep -o 'ELF.*')"
    else
        log "[qemu-ios] ✗ Binary not found!"
        find "${WORKDIR}" -name "qemu-system-arm" 2>/dev/null
        exit 1
    fi

    log "[qemu-ios] Done! Copy to Alpine rootfs overlays/usr/bin/"
}

main() {
    echo ""
    echo "============================================"
    echo "  QEMU-iOS Builder (Alpine/musl aarch64)"
    echo "  Target: iPod Touch 2G (arm-softmmu)"
    echo "============================================"
    echo ""

    if ! command -v docker &>/dev/null; then
        log "[!] Docker is required. Install: https://docs.docker.com/engine/install/"
        exit 1
    fi

    build_qemu_ios

    echo ""
    echo "Usage:"
    echo "  ./qemu-system-arm \\"
    echo "    -M iPod-Touch,bootrom=<bootrom>,nand=<nand_dir>,nor=<nor_dir> \\"
    echo "    -serial mon:stdio -cpu max -m 2G -d unimp"
}

main "$@"
