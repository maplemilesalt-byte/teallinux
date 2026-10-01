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

mkdir -p "$ROOTFS/etc/sudoers.d"
# Put every newly created regular user in the sudo group by default.
if [ -f "$ROOTFS/etc/adduser.conf" ]; then
    sed -i 's/^#*ADD_EXTRA_GROUPS=.*/ADD_EXTRA_GROUPS=1/' "$ROOTFS/etc/adduser.conf"
    if grep -q '^EXTRA_GROUPS=' "$ROOTFS/etc/adduser.conf"; then
        sed -i 's/^EXTRA_GROUPS=.*/EXTRA_GROUPS="sudo"/' "$ROOTFS/etc/adduser.conf"
    else
        printf '\nEXTRA_GROUPS="sudo"\n' >> "$ROOTFS/etc/adduser.conf"
    fi
fi

cat > "$ROOTFS/etc/sudoers.d/teal" <<'EOF'
# Teal Linux: sudo may run any command as root.
%sudo ALL=(ALL:ALL) ALL
EOF
chmod 0440 "$ROOTFS/etc/sudoers.d/teal"

mkdir -p "$ROOTFS/etc/teal"
cp "$PROJECT_DIR/config/packages" "$ROOTFS/etc/teal/packages"

echo "==> Root filesystem configured."
