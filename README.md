# Alpine RAM Rootfs for Xiaomi Raphael

Alpine Linux with OpenRC, running entirely in RAM (squashfs + overlayfs),
designed as a lightweight layer to launch QEMU guest VMs (e.g. qemu-ios)
on the Xiaomi Redmi K20 Pro (raphael).

## Concept

```
Boot → U-Boot → Kernel + Initramfs → Squashfs (Alpine) extracted to RAM
                                      ↓
                              OpenRC starts services
                                      ↓
                              qemu-ios (iPod Touch 2G emulation)
```

The entire rootfs sits in RAM via squashfs (read-only) + overlayfs on tmpfs (writable).
Kernel and initramfs live on the `cache` partition (FAT32, ~256 MB limit).

## Requirements

- Linux build host (x86_64 or aarch64) with:
  - `bash`, `curl`, `ar` (binutils), `tar`, `cpio`, `gzip`
  - `mksquashfs` (squashfs-tools)
- For qemu-ios build: Docker with multiarch support

## Usage

### Basic build (Alpine + OpenRC + kernel)

```bash
./build.sh
```

### With qemu-ios (iPod Touch 2G emulator)

```bash
BUILD_QEMU_IOS=true ./build.sh
```

### Custom kernel version

```bash
KERNEL_VERSION=7.0 ./build.sh
```

### Keep workdir for debugging

```bash
KEEP_WORKDIR=true ./build.sh
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KERNEL_VERSION` | `7.0` | Kernel version tag from GengWei1997 |
| `ALPINE_VERSION` | `latest-stable` | Alpine branch |
| `BUILD_QEMU_IOS` | `false` | Set to `true` to build qemu-ios |
| `GH_MIRROR` | (empty) | GitHub mirror, e.g. `https://ghfast.top/` |
| `KEEP_WORKDIR` | `false` | Keep build temp directory |
| `OUTPUT` | `./output` | Output directory |

## Output

```
output/
├── linux.efi              # Kernel (vmlinuz)
├── initramfs              # Initramfs with Alpine squashfs
├── dtbs/                  # Device tree blobs
├── boot.img               # FAT32 partition image (optional)
└── qemu-system-arm        # qemu-ios binary (when BUILD_QEMU_IOS=true)
```

## Flashing

```bash
adb reboot bootloader

# Flash bootloader (once)
fastboot flash boot u-boot.img

# Flash kernel + initramfs (using boot.img)
fastboot flash cache boot.img

fastboot reboot
```

## qemu-ios Auto-Launch (OpenRC)

When `BUILD_QEMU_IOS=true`, the system includes an OpenRC service `qemu-ios`.

Before running, configure paths on the device:

```bash
# Edit paths to your bootrom/NAND/NOR files
vim /etc/qemu-ios/env

# Start manually
rc-service qemu-ios start

# Or enable at boot
rc-update add qemu-ios default
```

Download required files from [qemu-ios releases](https://github.com/devos50/qemu-ios/releases/tag/n72ap_v1):
- S5L8720 bootrom binary
- NOR image
- NAND image

Place them on the userdata partition (e.g. `/mnt/userdata/qemu-ios/`).

## Size Budget

| Component | Size |
|-----------|------|
| Kernel (linux.efi) | ~14 MB |
| Initramfs (Alpine + busybox) | ~50-80 MB |
| qemu-ios binary | ~30-50 MB (optional) |
| **Total (without qemu)** | **~64-94 MB** |
| **Total (with qemu)** | **~94-144 MB** |
| Cache partition limit | 256 MB ✓ |

## Project Structure

```
build-alpine-ram/
├── build.sh                  # Main build script
├── build-qemu-ios.sh          # qemu-ios cross-build via Docker
├── initramfs/init             # Init script (squashfs → overlay → switch_root)
├── overlays/
│   ├── etc/
│   │   ├── init.d/qemu-ios    # OpenRC service for auto-launch
│   │   ├── motd               # Welcome message
│   │   └── profile.d/aliases.sh
└── output/
