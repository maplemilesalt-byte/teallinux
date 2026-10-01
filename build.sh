#!/bin/bash
set -euo pipefail

# Teal Linux - minimal Debian-based root filesystem builder

SUITE="${SUITE:-stable}"
ARCH="${ARCH:-amd64}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
ROOTFS="${ROOTFS:-build/rootfs}"

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/config/packages"
PROFILE_DIR="$SCRIPT_DIR/config/profiles"
INSTALL_MODE="${INSTALL_MODE:-terminal}"
EDITOR="${EDITOR:-nano}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: build.sh must be run as root."
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "Error: debootstrap is required."
    echo "Install it with: apt install debootstrap"
    exit 1
fi

if [[ "$INSTALL_MODE" != "terminal" && "$INSTALL_MODE" != "x11" ]]; then
    echo "Error: INSTALL_MODE must be terminal or x11."
    exit 1
fi
if [[ "$EDITOR" != "nano" && "$EDITOR" != "vim" ]]; then
    echo "Error: EDITOR must be nano or vim."
    exit 1
fi

PROFILE_FILE="$PROFILE_DIR/$INSTALL_MODE"
EDITOR_FILE="$PROFILE_DIR/editor-$EDITOR"

if [ ! -f "$PACKAGE_FILE" ]; then
    echo "Error: package list not found: $PACKAGE_FILE"
    exit 1
fi

echo "==> Building Teal Linux root filesystem"
echo "    Debian suite: $SUITE"
echo "    Architecture: $ARCH"
echo "    Root filesystem: $ROOTFS"
echo "    Interface: $INSTALL_MODE"
echo "    Editor: $EDITOR"

mkdir -p "$(dirname "$ROOTFS")"

if [ -d "$ROOTFS" ] && [ -n "$(find "$ROOTFS" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Error: $ROOTFS is not empty."
    echo "Remove it first if you want a clean build."
    exit 1
fi

PACKAGES="$(
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$PACKAGE_FILE" "$PROFILE_FILE" "$EDITOR_FILE" |
    tr '
' ',' |
    sed 's/,$//'
)"

debootstrap     --arch="$ARCH"     --variant=minbase     --include="$PACKAGES"     "$SUITE"     "$ROOTFS"     "$MIRROR"

"$SCRIPT_DIR/scripts/configure-rootfs.sh" "$ROOTFS"

echo
echo "==> Teal Linux root filesystem created successfully."
echo "    Location: $ROOTFS"
