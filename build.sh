#!/bin/bash
set -euo pipefail

# Teal Linux - minimal Debian-based root filesystem builder

SUITE="${SUITE:-stable}"
ARCH="${ARCH:-amd64}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"

# CachyOS/Arch systems may export CPU-specific ARCH values such as
# x86_64_v2/v3/v4. Debian amd64 is the correct target for all of them.
case "$ARCH" in
    x86_64|x86_64_v2|x86_64_v3|x86_64_v4)
        ARCH="amd64"
        ;;
esac
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

# CachyOS ships multiple CPU architecture values in pacman-conf, while
# debootstrap expects a single host architecture. Use its documented
# host-architecture override temporarily when running on Arch/CachyOS.
DEBOOTSTRAP_ARCH_FILE="/usr/share/debootstrap/arch"
DEBOOTSTRAP_ARCH_FILE_CREATED=0
DEBOOTSTRAP_ARCH_FILE_BACKUP=""
cleanup_debootstrap_arch() {
    if [ "$DEBOOTSTRAP_ARCH_FILE_CREATED" -eq 1 ]; then
        rm -f "$DEBOOTSTRAP_ARCH_FILE"
    elif [ -n "$DEBOOTSTRAP_ARCH_FILE_BACKUP" ]; then
        cat "$DEBOOTSTRAP_ARCH_FILE_BACKUP" > "$DEBOOTSTRAP_ARCH_FILE"
        rm -f "$DEBOOTSTRAP_ARCH_FILE_BACKUP"
    fi
}
trap cleanup_debootstrap_arch EXIT

if command -v pacman-conf >/dev/null 2>&1 && [ ! -e "$DEBOOTSTRAP_ARCH_FILE" ]; then
    case "$(pacman-conf Architecture | head -n 1)" in
        x86_64)
            printf "%s\n" "amd64" > "$DEBOOTSTRAP_ARCH_FILE"
            DEBOOTSTRAP_ARCH_FILE_CREATED=1
            ;;
    esac
fi

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
