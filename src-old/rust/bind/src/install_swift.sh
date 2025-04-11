#!/bin/bash

# Script to install Swift on Ubuntu ARM64 (aarch64)
# This script installs the latest stable version of Swift

set -e

echo "Swift Installation Script for Ubuntu ARM64"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Check if we're on Ubuntu
if [ ! -f /etc/lsb-release ] || ! grep -q "Ubuntu" /etc/lsb-release; then
  echo "Warning: This script is designed for Ubuntu. Your system may not be compatible."
  echo "Continuing installation anyway..."
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
  echo "This script is designed for ARM64/aarch64 architecture. Your architecture is $ARCH."
  exit 1
fi

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y \
  binutils \
  git \
  wget \
  gnupg2 \
  libc6-dev \
  libcurl4 \
  libedit2 \
  libgcc-9-dev \
  libpython3.8 \
  libsqlite3-0 \
  libstdc++-9-dev \
  libxml2 \
  libz3-dev \
  libncurses6 \
  pkg-config \
  tzdata \
  unzip \
  zlib1g-dev

# Determine the latest Swift version
echo "Determining the latest Swift version for ARM64..."
SWIFT_RELEASES_URL="https://www.swift.org/download/"
LATEST_SWIFT_VERSION='6.0.3'

if [ -z "$LATEST_SWIFT_VERSION" ]; then
  echo "Unable to determine the latest Swift version. Please check manually at $SWIFT_RELEASES_URL"
  exit 1
fi

echo "Latest Swift version: $LATEST_SWIFT_VERSION"

# Create download URL for ARM64
SWIFT_PACKAGE="swift-$LATEST_SWIFT_VERSION-RELEASE-ubuntu22.04-aarch64"
SWIFT_URL="https://download.swift.org/swift-$LATEST_SWIFT_VERSION-release/ubuntu2204-aarch64/swift-$LATEST_SWIFT_VERSION-RELEASE/swift-$LATEST_SWIFT_VERSION-RELEASE-ubuntu22.04-aarch64.tar.gz"

# Download Swift
echo "Downloading Swift $LATEST_SWIFT_VERSION for Ubuntu ARM64..."
cd /tmp
wget $SWIFT_URL || {
  echo "Failed to download Swift. Please check the URL: $SWIFT_URL"
  exit 1
}
wget "$SWIFT_URL.sig" || {
  echo "Failed to download Swift signature file. Please check the URL: $SWIFT_URL.sig"
  exit 1
}

# Verify the download (optional step)
echo "Verifying download..."
wget -q -O - https://swift.org/keys/all-keys.asc | gpg --import -
gpg --verify "$SWIFT_PACKAGE.tar.gz.sig"

# Install Swift
echo "Installing Swift..."
tar xzf "$SWIFT_PACKAGE.tar.gz"
mkdir -p /opt/swift
mv "$SWIFT_PACKAGE" /opt/swift/

# Add Swift to PATH
echo "Adding Swift and swiftc to PATH..."
echo 'export PATH=/opt/swift/'"$SWIFT_PACKAGE"'/usr/bin:$PATH' > /etc/profile.d/swift.sh
chmod +x /etc/profile.d/swift.sh

# Create symbolic links to make Swift tools accessible to all users
ln -sf /opt/swift/"$SWIFT_PACKAGE"/usr/bin/swift /usr/local/bin/swift
ln -sf /opt/swift/"$SWIFT_PACKAGE"/usr/bin/swiftc /usr/local/bin/swiftc

# Clean up
echo "Cleaning up..."
rm -f /tmp/"$SWIFT_PACKAGE.tar.gz"
rm -f /tmp/"$SWIFT_PACKAGE.tar.gz.sig"

echo "Swift $LATEST_SWIFT_VERSION has been installed successfully."
echo "Please restart your shell or run: source /etc/profile.d/swift.sh"
swift --version
