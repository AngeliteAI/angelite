#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

clear
rm -rf ./build

# --- Project Directories ---
ROOT_DIR="/Users/solmidnight/work" # Make sure this is correct for your setup
SWIFT_SRC_DIR="$ROOT_DIR/angelite/src/swift"
GFX_SRC_DIR="$SWIFT_SRC_DIR/gfx/src"
GFX_TEST_SRC_DIR="$SWIFT_SRC_DIR/gfx-test/src"
MATH_SRC_DIR="$ROOT_DIR/angelite/src/zig/math"
MATH_SWIFT_SRC_DIR="$SWIFT_SRC_DIR/math/src"
BUILD_DIR="$SWIFT_SRC_DIR/build"

echo "Starting build process..."

# --- Setup SDK Path Dynamically ---
OSX_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
if [ -z "$OSX_SDK_PATH" ]; then
    echo "Error: Could not determine macOS SDK path. Make sure Xcode is installed and xcrun is in your PATH."
    exit 1
fi
OSX_SDK_FRAMEWORKS_DIR="$OSX_SDK_PATH/System/Library/Frameworks"
# OSX_SDK_INCLUDE_DIR="$OSX_SDK_PATH/usr/include" # Usually not needed when using -sdk

echo "Using macOS SDK path: $OSX_SDK_PATH"

# --- Create Build Directory ---
mkdir -p "$BUILD_DIR"
echo "Build directory: $BUILD_DIR"

# --- Build Zig Math Static Library ---
echo "Building Zig math library..."
cd "$MATH_SRC_DIR"
zig build -Doptimize=ReleaseFast # Or -Doptimize=Debug, etc.
ZIG_MATH_LIB_PATH="$MATH_SRC_DIR/zig-out/lib/libmath.a" # Explicitly target the static archive
if [ ! -f "$ZIG_MATH_LIB_PATH" ]; then
    echo "Error: Zig math static library build failed or not found at: $ZIG_MATH_LIB_PATH"
    exit 1
fi
cp "$ZIG_MATH_LIB_PATH" "$BUILD_DIR/libmath.a"
echo "Successfully built and copied static math library to: $BUILD_DIR/libmath.a"
# Return to the swift build script directory
cd "$SWIFT_SRC_DIR"

# --- Find Swift Source Files ---
MATH_SWIFT_FILES=$(find "$MATH_SWIFT_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')
GFX_SWIFT_FILES=$(find "$GFX_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')
GFX_TEST_SWIFT_FILES=$(find "$GFX_TEST_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')

# --- Build Swift Components ---

# STEP 1: Build Math module (interface)
echo "Building Math module interface..."
swiftc -parse-as-library -emit-module -module-name Math \
    -emit-module-path "$BUILD_DIR/Math.swiftmodule" \
    $MATH_SWIFT_FILES

# STEP 2: Build Math library (implementation, FORCING static link of libmath.a)
echo "Building Math library (force-loading libmath.a statically)..."
swiftc -parse-as-library -emit-library -o "$BUILD_DIR/libMath.dylib" \
    -module-name Math \
    $MATH_SWIFT_FILES \
    -L"$BUILD_DIR" \
    -Xlinker -force_load -Xlinker "$BUILD_DIR/libmath.a" # <-- THE FIX: Force load the static lib
    # No need for -lmath when using -force_load path

# STEP 3: Build Gfx module (interface)
echo "Building Gfx module interface..."
swiftc -parse-as-library -emit-module -module-name Gfx \
    -emit-module-path "$BUILD_DIR/Gfx.swiftmodule" \
    -I "$BUILD_DIR" \
    $GFX_SWIFT_FILES

# STEP 4: Build Gfx library (implementation, linking libMath.dylib)
echo "Building Gfx library (linking libMath.dylib)..."
swiftc -parse-as-library -emit-library -o "$BUILD_DIR/libGfx.dylib" \
    -module-name Gfx \
    -I "$BUILD_DIR" \
    $GFX_SWIFT_FILES \
    -L "$BUILD_DIR" -lMath \
    -sdk "$OSX_SDK_PATH" \
    -F"$OSX_SDK_FRAMEWORKS_DIR" \
    -framework Cocoa -framework Metal -framework MetalKit \
    -Xlinker -rpath -Xlinker @executable_path # Rpath for finding libMath.dylib at runtime

# STEP 5: Build gfx-test executable (linking libGfx.dylib and libMath.dylib)
echo "Building gfx-test executable..."
swiftc -o "$BUILD_DIR/gfx-test" \
    $GFX_TEST_SWIFT_FILES \
    -I "$BUILD_DIR" \
    -L "$BUILD_DIR" -lGfx -lMath \
    -sdk "$OSX_SDK_PATH" \
    -F"$OSX_SDK_FRAMEWORKS_DIR" \
    -framework Cocoa -framework Metal -framework MetalKit \
    -Xlinker -rpath -Xlinker @executable_path \
    -Xlinker -rpath -Xlinker "$BUILD_DIR" # Rpaths for finding dylibs at runtime

# --- Run ---
echo "Build process finished successfully."
echo "--- Products ---"
echo "Zig Static Lib: $BUILD_DIR/libmath.a"
echo "Math Module:    $BUILD_DIR/Math.swiftmodule"
echo "Math Library:   $BUILD_DIR/libMath.dylib"
echo "Gfx Module:     $BUILD_DIR/Gfx.swiftmodule"
echo "Gfx Library:    $BUILD_DIR/libGfx.dylib"
echo "Executable:     $BUILD_DIR/gfx-test"
echo "----------------"
echo "Running gfx-test..."
cd "$BUILD_DIR" && ./gfx-test
