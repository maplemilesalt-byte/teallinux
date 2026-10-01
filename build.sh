#!/bin/bash
set -euo pipefail

# Teal Linux - minimal Debian-based root filesystem builder

SUITE="${SUITE:-stable}"
ARCH="${ARCH:-amd64}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
ROOTFS="${ROOTFS:-build/rootfs}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: build.sh must be run as root."
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "Error: debootstrap is required."
    echo "Install it with: apt install debootstrap"
    exit 1
fi

echo "==> Building Teal Linux root filesystem"
echo "    Debian suite: $SUITE"
echo "    Architecture: $ARCH"
echo "    Root filesystem: $ROOTFS"

mkdir -p "$(dirname "$ROOTFS")"

if [ -d "$ROOTFS" ] && [ -n "$(find "$ROOTFS" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Error: $ROOTFS is not empty."
    echo "Remove it first if you want a clean build."
    exit 1
fi

debootstrap \
    --arch="$ARCH" \
    --variant=minbase \
    "$SUITE" \
    "$ROOTFS" \
    "$MIRROR"

echo
echo "==> Teal Linux root filesystem created successfully."
echo "    Location: $ROOTFS"
