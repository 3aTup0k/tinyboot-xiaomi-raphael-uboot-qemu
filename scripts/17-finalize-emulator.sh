#!/bin/bash
set -e

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [17] ⚙️ Finalizing Emulator and Autostart"

if [[ "$SYSTEM_TYPE" != "tinyboot-iphoneos" ]]; then
    echo "Skipping emulator finalization for $SYSTEM_TYPE"
    exit 0
fi

# 1. Install Binary and Assets from artifacts to rootdir
echo "Installing binary and assets to rootfs..."
cp build_artifacts/qemu-system-arm rootdir/usr/bin/
cp -r build_artifacts/opt rootdir/

# Ensure binary is executable and owned by root
chmod +x rootdir/usr/bin/qemu-system-arm
chown root:root rootdir/usr/bin/qemu-system-arm 2>/dev/null || true

# 2. Create the wrapper script for direct screen output
echo "Creating wrapper script /usr/bin/start-ipod.sh..."
cat <<EOF > rootdir/usr/bin/start-ipod.sh
#!/bin/bash
export SDL_VIDEODRIVER=kmsdrm
export SDL_FBDEV=/dev/fb0

exec /usr/bin/qemu-system-arm -M iPod-Touch,bootrom=/opt/ipod-emu/bootrom_240_4,nand=/opt/ipod-emu/nand,nor=/opt/ipod-emu/nor_n72ap.bin -serial mon:stdio -display sdl
EOF

chmod +x rootdir/usr/bin/start-ipod.sh

# 3. Create systemd service for autonomous boot
echo "Creating systemd service for autonomous boot..."
mkdir -p rootdir/etc/systemd/system

cat <<EOF > rootdir/etc/systemd/system/ipod-emu.service
[Unit]
Description=iPod Touch 2G Emulator
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/start-ipod.sh
StandardOutput=journal
StandardError=journal
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
ln -sf /etc/systemd/system/ipod-emu.service rootdir/etc/systemd/system/multi-user.target.wants/ipod-emu.service

echo "[$(date +'%Y-%m-%d %H:%M:%S')] [17] ✅ Emulator installed and set to autonomous boot via systemd"
