#!/bin/bash
set -e

ROOT_DIR="/Users/solmidnight/work"
SWIFT_SRC_DIR="$ROOT_DIR/angelite/src/swift"
GFX_SRC_DIR="$SWIFT_SRC_DIR/gfx/src"
MATH_SRC_DIR="$ROOT_DIR/angelite/src/zig/math"
BUILD_DIR="$SWIFT_SRC_DIR/build"

echo "Starting build process..."

# --- Setup SDK Path Dynamically ---
OSX_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
if [ -z "$OSX_SDK_PATH" ]; then
    echo "Error: Could not determine macOS SDK path. Make sure Xcode is installed and xcrun is in your PATH."
    exit 1
fi
OSX_SDK_FRAMEWORKS_DIR="$OSX_SDK_PATH/System/Library/Frameworks"
OSX_SDK_INCLUDE_DIR="$OSX_SDK_PATH/usr/include"

echo "Using macOS SDK path: $OSX_SDK_PATH"

# --- Create build directory ---
mkdir -p "$BUILD_DIR"
rm -f "$BUILD_DIR/HelloTriangle" # Executable will be in BUILD_DIR

# --- Compile Metal shaders ---
cd "$GFX_SRC_DIR"
if [ -f "Shaders.metal" ]; then
    echo "Compiling Shaders.metal..."
    xcrun -sdk macosx metal -c Shaders.metal -o "$BUILD_DIR/Shaders.air"
    xcrun -sdk macosx metallib "$BUILD_DIR/Shaders.air" -o "$BUILD_DIR/default.metallib"
else
    echo "Warning: Shaders.metal not found, skipping shader compilation"
fi

# --- Build Zig math library using zig build ---
echo "Building Zig math library using zig build..."
cd "$MATH_SRC_DIR"
zig build -Doptimize=ReleaseFast # Adjust optimize as needed
ZIG_MATH_LIB_PATH="$MATH_SRC_DIR/zig-out/lib/libmath.a"
if [ ! -f "$ZIG_MATH_LIB_PATH" ]; then
    echo "Error: Zig math library build failed or library not found at: $ZIG_MATH_LIB_PATH"
    exit 1
fi
echo "Successfully built static math library at: $ZIG_MATH_LIB_PATH"


cd "$SWIFT_SRC_DIR" # Go back to Swift source directory


# --- Find all Swift files ---
SWIFT_FILES=""
while IFS= read -r -d $'\0' swift_file; do
    SWIFT_FILES="$SWIFT_FILES $swift_file"
done < <(find "$SWIFT_SRC_DIR" -name "*.swift" -type f -print0)

# --- Compile and link Swift with Zig math library and frameworks ---
echo "Compiling and linking Swift with Zig math library and frameworks..."
swiftc -parse-as-library -o "$BUILD_DIR/HelloTriangle" \
    $SWIFT_FILES \
    "$ZIG_MATH_LIB_PATH" \
    -sdk "$OSX_SDK_PATH" \
    -I"$OSX_SDK_INCLUDE_DIR" \
    -F"$OSX_SDK_FRAMEWORKS_DIR" \
    -framework Cocoa -framework Metal -framework MetalKit


# --- Run the executable ---
cd "$BUILD_DIR" # Change directory to where the executable is built
if [ -f "./HelloTriangle" ]; then
    echo "Running HelloTriangle..."
    ./HelloTriangle
else
    echo "Error: Compilation failed, executable not found in build directory."
    exit 1
fi

echo "Build process finished."
