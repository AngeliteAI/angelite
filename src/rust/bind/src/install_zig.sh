#!/bin/bash
set -e

# Script for installing Zig on Ubuntu Docker container (x86_64)

# Update package repository
apt-get update

# Install dependencies
apt-get install -y \
    curl \
    xz-utils \
    tar

# Set Zig version to install
ZIG_VERSION="0.14.0"

# Download Zig for x86_64
echo "Downloading Zig $ZIG_VERSION for x86_64..."
curl -L -o zig.tar.xz "https://ziglang.org/download/$ZIG_VERSION/zig-linux-x86_64-$ZIG_VERSION.tar.xz"

# Extract Zig
mkdir -p /opt/zig
tar -xf zig.tar.xz -C /opt/zig --strip-components=1
rm zig.tar.xz

# Add Zig to PATH
echo 'export PATH="/opt/zig:$PATH"' >> /etc/profile.d/zig.sh
echo 'export PATH="/opt/zig:$PATH"' >> ~/.bashrc
export PATH="/opt/zig:$PATH"

# Create symlink in /usr/local/bin for easier access
ln -sf /opt/zig/zig /usr/local/bin/zig

# Verify installation
zig version

echo "Zig has been successfully installed on Ubuntu!"
