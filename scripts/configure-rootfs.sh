#!/bin/bash
set -euo pipefail

ROOTFS="${1:?Usage: configure-rootfs.sh <rootfs>}"

if [ ! -d "$ROOTFS/etc" ]; then
    echo "Error: $ROOTFS does not look like a root filesystem."
    exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Configuring Teal Linux root filesystem"

cp "$PROJECT_DIR/config/os-release" "$ROOTFS/etc/os-release"
cp "$PROJECT_DIR/config/hostname" "$ROOTFS/etc/hostname"

mkdir -p "$ROOTFS/etc/ssh/sshd_config.d"
cat > "$ROOTFS/etc/ssh/sshd_config.d/teal.conf" <<'EOF'
# Teal Linux SSH defaults
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
UsePAM yes
EOF

mkdir -p "$ROOTFS/etc/teal"
cp "$PROJECT_DIR/config/packages" "$ROOTFS/etc/teal/packages"

echo "==> Root filesystem configured."
