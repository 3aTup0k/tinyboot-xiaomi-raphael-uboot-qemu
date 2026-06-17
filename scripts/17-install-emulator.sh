#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [17] 📦 Installing pre-built emulator and assets to rootfs"

if [[ "$SYSTEM_TYPE" != "tinyfs-iphoneos" ]]; then
    echo "Skipping emulator installation for $SYSTEM_TYPE"
    exit 0
fi

# Check if artifacts exist
if [ ! -f "build_artifacts/qemu-system-arm" ]; then
    echo "Error: Pre-built emulator binary not found in build_artifacts/"
    exit 1
fi

# Copy binary
cp build_artifacts/qemu-system-arm rootdir/usr/bin/

# Copy assets
cp -r build_artifacts/opt rootdir/

# 3. Create OpenRC service and wrapper for instant boot to screen
echo "Creating OpenRC service and wrapper for the emulator..."

# Create a wrapper script to set environment variables for SDL2
cat <<EOF > rootdir/usr/bin/start-ipod.sh
#!/bin/bash
# Force SDL to use the Linux Framebuffer/DRM for direct screen output
export SDL_VIDEODRIVER=kmsdrm
export SDL_FBDEV=/dev/fb0

# Launch emulator
exec /usr/bin/qemu-system-arm -M iPod-Touch,bootrom=/opt/ipod-emu/bootrom,nand=/opt/ipod-emu/nand,nor=/opt/ipod-emu/nor -serial mon:stdio -cpu max -m 2G -d unimp -display sdl
EOF

chmod +x rootdir/usr/bin/start-ipod.sh

# Create the OpenRC service
cat <<EOF > rootdir/etc/init.d/ipod-emu
#!/sbin/openrc-run
description="iPod Touch 2G Emulator - Direct to Screen"

command="/usr/bin/start-ipod.sh"
command_background="no"

depend() {
    need net
    after firewall
}
EOF

chmod +x rootdir/etc/init.d/ipod-emu

# Enable service in default runlevel
mkdir -p rootdir/etc/runlevels/default
ln -sf /etc/init.d/ipod-emu rootdir/etc/runlevels/default/ipod-emu

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [17] ✅ Emulator installation completed"
