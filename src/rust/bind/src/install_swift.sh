#!/bin/bash
set -e

# Script for installing Swift on Ubuntu Docker container (x86_64)

# Update package repository
apt-get update

# Install dependencies required for Swift
apt-get install -y \
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4 \
    libedit2 \
    libgcc-9-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-9-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
    curl \
    wget

# Set Swift version
SWIFT_VERSION="5.10"

# Add Swift repository key
wget -q -O - https://swift.org/keys/all-keys.asc | gpg --import -

# Download Swift for Ubuntu
echo "Downloading Swift $SWIFT_VERSION for Ubuntu..."
wget https://download.swift.org/swift-$SWIFT_VERSION-release/ubuntu2204/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-ubuntu22.04.tar.gz
wget https://download.swift.org/swift-$SWIFT_VERSION-release/ubuntu2204/swift-$SWIFT_VERSION-RELEASE/swift-$SWIFT_VERSION-RELEASE-ubuntu22.04.tar.gz.sig

# Verify download (optional, can be removed if causing issues)
gpg --verify swift-$SWIFT_VERSION-RELEASE-ubuntu22.04.tar.gz.sig

# Extract Swift
mkdir -p /opt/swift
tar -xzf swift-$SWIFT_VERSION-RELEASE-ubuntu22.04.tar.gz -C /opt/swift --strip-components=1
rm swift-$SWIFT_VERSION-RELEASE-ubuntu22.04.tar.gz*

# Add Swift to PATH
echo 'export PATH="/opt/swift/usr/bin:$PATH"' > /etc/profile.d/swift.sh
echo 'export PATH="/opt/swift/usr/bin:$PATH"' >> ~/.bashrc
chmod +x /etc/profile.d/swift.sh
export PATH="/opt/swift/usr/bin:$PATH"

# Create symlink in /usr/local/bin for easier access
ln -sf /opt/swift/usr/bin/swift /usr/local/bin/swift

# Test Swift installation
echo 'print("Hello from Swift!")' > test.swift
swift test.swift
rm test.swift

echo "Swift has been successfully installed on Ubuntu!"
