#!/bin/bash
set -euo pipefail

# Teal Linux - build a bootable BIOS disk image from build/rootfs

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOTFS="${ROOTFS:-$PROJECT_DIR/build/rootfs}"
IMAGE="${IMAGE:-$PROJECT_DIR/build/teal.img}"
SIZE="\${SIZE:-2G}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: build-image.sh must be run as root."
    exit 1
fi

for command in truncate sfdisk losetup mkfs.ext4 mount umount rsync grub-install blkid; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: required command not found: $command"
        exit 1
    fi
done

if [ ! -d "$ROOTFS/etc" ]; then
    echo "Error: root filesystem not found: $ROOTFS"
    echo "Run ./build.sh first."
    exit 1
fi

if ! compgen -G "$ROOTFS/boot/vmlinuz-*" >/dev/null; then
    echo "Error: no Linux kernel found in $ROOTFS/boot."
    echo "Rebuild the root filesystem after adding linux-image-amd64."
    exit 1
fi

mkdir -p "$(dirname "$IMAGE")"

if [ -e "$IMAGE" ]; then
    echo "Error: image already exists: $IMAGE"
    echo "Remove it first if you want a fresh image."
    exit 1
fi

LOOP=""
MOUNTPOINT=""

cleanup() {
    set +e
    if [ -n "$MOUNTPOINT" ]; then
        umount "$MOUNTPOINT" 2>/dev/null || true
    fi
    if [ -n "$LOOP" ]; then
        losetup -d "$LOOP" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "==> Creating Teal Linux disk image"
echo "    Image: $IMAGE"
echo "    Size:  $SIZE"

truncate -s "$SIZE" "$IMAGE"

sfdisk "$IMAGE" <<'EOF'
label: dos
unit: sectors

start=2048, type=83, bootable
EOF

LOOP="$(losetup --find --show --partscan "$IMAGE")"
PART="${LOOP}p1"

if [ ! -b "$PART" ]; then
    echo "Error: partition device was not created: $PART"
    exit 1
fi

echo "==> Formatting root partition"
mkfs.ext4 -F -L TEAL_ROOT "$PART" >/dev/null

MOUNTPOINT="$(mktemp -d)"
mount "$PART" "$MOUNTPOINT"

echo "==> Copying Teal Linux root filesystem"
rsync -aHAX --numeric-ids "$ROOTFS"/ "$MOUNTPOINT"/

ROOT_UUID="$(blkid -s UUID -o value "$PART")"

cat > "$MOUNTPOINT/etc/fstab" <<EOF
# Teal Linux filesystem table
UUID=$ROOT_UUID / ext4 defaults 0 1
EOF

: > "$MOUNTPOINT/etc/machine-id"

echo "==> Installing GRUB for BIOS boot"
grub-install \
    --target=i386-pc \
    --boot-directory="$MOUNTPOINT/boot" \
    --recheck \
    "$LOOP"

mkdir -p "$MOUNTPOINT/boot/grub"

KERNEL="$(basename "$(compgen -G "$MOUNTPOINT/boot/vmlinuz-*" | head -n 1)")"
INITRD="$(basename "$(compgen -G "$MOUNTPOINT/boot/initrd.img-*" | head -n 1)")"

cat > "$MOUNTPOINT/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0

menuentry 'Teal Linux' {
    insmod ext2
    search --no-floppy --fs-uuid --set=root $ROOT_UUID
    linux /boot/$KERNEL root=UUID=$ROOT_UUID ro
    initrd /boot/$INITRD
}
EOF

sync

echo
echo "==> Teal Linux bootable image created successfully."
echo "    Location: $IMAGE"
echo "    Boot mode: BIOS/Legacy"
