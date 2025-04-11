#!/bin/bash
# filepath: /root/angelite/setup_shaderc.sh

set -e  # Exit immediately if a command exits with a non-zero status

echo "Setting up shaderc from scratch..."

# Go to project root
cd /root/angelite

# Create vendor directory if it doesn't exist
mkdir -p vendor

# Remove any existing shaderc
if [ -d "vendor/shaderc" ]; then
  echo "Removing existing shaderc..."
  rm -rf vendor/shaderc
fi

# Clone shaderc and its dependencies
echo "Cloning shaderc..."
cd vendor
git clone https://github.com/google/shaderc.git
cd shaderc

# Update the dependencies (instead of recursive submodule)
./utils/git-sync-deps

# Build shaderc
echo "Building shaderc from source..."
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DSHADERC_SKIP_TESTS=ON \
      -DSHADERC_SKIP_EXAMPLES=ON \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      ..
make -j$(nproc)

# Update the run.sh script
echo "Updating run.sh script..."
cat > /root/angelite/src/zig/gfx/run.sh << 'EOF'
#!/bin/bash
# filepath: /root/angelite/src/zig/gfx/run.sh
zig run \
  -lc \
  -lvulkan \
  -lxcb \
  -lstdc++ \
  -I /usr/include/ \
  -I /usr/include/x86_64-linux-gnu \
  -I /root/angelite/vendor/shaderc/include \
  -L /root/angelite/vendor/shaderc/build/lib \
  -lshaderc_combined \
  main.zig
EOF

chmod +x /root/angelite/src/zig/gfx/run.sh

echo "Done! shaderc has been set up and built from source."
echo "The run.sh script has been updated to use the local build."
echo "You can now run your application with: ./run.sh"