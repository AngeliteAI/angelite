#!/bin/bash
# filepath: /root/angelite/run.sh
set -e # Exit immediately if a command exits with a non-zero status.

# Get the absolute path to the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Project root: $PROJECT_ROOT"

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    # --- macOS - Run Swift implementation ---
    echo "Detected macOS - Running Swift implementation"
    
    # --- Project Directories ---
    ROOT_DIR="${ROOT_DIR:-$PROJECT_ROOT}"
    GFX_SRC_DIR="$ROOT_DIR/src/gfx/src/macos"
    GFX_TEST_SRC_DIR="$ROOT_DIR/src/gfx-swift-test/src"
    MATH_SRC_DIR="$ROOT_DIR/src/math/src"
    MATH_SWIFT_SRC_DIR="$ROOT_DIR/src/math/bindings/macos"
    BUILD_DIR="$ROOT_DIR/build"
    
    # Check if the executable exists, if not, run the build script
    if [ ! -f "$BUILD_DIR/gfx-test" ]; then
        echo "Swift executable not found. Running the build script..."
        
        # --- Setup SDK Path Dynamically ---
        OSX_SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        if [ -z "$OSX_SDK_PATH" ]; then
            echo "Error: Could not determine macOS SDK path. Make sure Xcode is installed."
            exit 1
        fi
        OSX_SDK_FRAMEWORKS_DIR="$OSX_SDK_PATH/System/Library/Frameworks"
        
        # Create Build Directory
        mkdir -p "$BUILD_DIR"
        
        # Compile Metal Shaders if they exist
        if [ -f "$GFX_SRC_DIR/Shaders.metal" ]; then
            echo "Compiling Shaders.metal..."
            xcrun -sdk macosx metal -c "$GFX_SRC_DIR/Shaders.metal" -o "$BUILD_DIR/Shaders.air"
            xcrun -sdk macosx metallib "$BUILD_DIR/Shaders.air" -o "$BUILD_DIR/default.metallib"
        fi
        
        # Build Zig Math Library
        echo "Building Zig math library..."
        cd "$MATH_SRC_DIR"
        zig build -Doptimize=ReleaseFast
        ZIG_MATH_LIB_PATH="$MATH_SRC_DIR/../zig-out/lib/libmath.a"
        if [ ! -f "$ZIG_MATH_LIB_PATH" ]; then
            echo "Error: Zig math static library build failed or not found."
            exit 1
        fi
        cp "$ZIG_MATH_LIB_PATH" "$BUILD_DIR/libmath.a"
        
        # Find Swift source files
        MATH_SWIFT_FILES=$(find "$MATH_SWIFT_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')
        GFX_SWIFT_FILES=$(find "$GFX_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')
        GFX_TEST_SWIFT_FILES=$(find "$GFX_TEST_SRC_DIR" -name "*.swift" -type f | tr '\n' ' ')
        
        # Build Math module and library
        cd "$MATH_SWIFT_SRC_DIR"
        echo "Building Math module interface..."
        swiftc -parse-as-library -emit-module -module-name Math \
            -emit-module-path "$BUILD_DIR/Math.swiftmodule" \
            $MATH_SWIFT_FILES
            
        echo "Building Math library..."
        swiftc -parse-as-library -emit-library -o "$BUILD_DIR/libMath.dylib" \
            -module-name Math \
            $MATH_SWIFT_FILES \
            -L"$BUILD_DIR" \
            -Xlinker -force_load -Xlinker "$BUILD_DIR/libmath.a"
            
        # Build Gfx module and library
        echo "Building Gfx module interface..."
        swiftc -parse-as-library -emit-module -module-name Gfx \
            -emit-module-path "$BUILD_DIR/Gfx.swiftmodule" \
            -I "$BUILD_DIR" \
            $GFX_SWIFT_FILES
            
        echo "Building Gfx library..."
        swiftc -parse-as-library -emit-library -o "$BUILD_DIR/libGfx.dylib" \
            -module-name Gfx \
            -I "$BUILD_DIR" \
            $GFX_SWIFT_FILES \
            -L "$BUILD_DIR" -lMath \
            -sdk "$OSX_SDK_PATH" \
            -F"$OSX_SDK_FRAMEWORKS_DIR" \
            -framework Cocoa -framework Metal -framework MetalKit \
            -Xlinker -rpath -Xlinker @executable_path
            
        # Build executable
        echo "Building gfx-test executable..."
        swiftc -o "$BUILD_DIR/gfx-test" \
            $GFX_TEST_SWIFT_FILES \
            -I "$BUILD_DIR" \
            -L "$BUILD_DIR" -lGfx -lMath \
            -sdk "$OSX_SDK_PATH" \
            -F"$OSX_SDK_FRAMEWORKS_DIR" \
            -framework Cocoa -framework Metal -framework MetalKit \
            -Xlinker -rpath -Xlinker @executable_path \
            -Xlinker -rpath -Xlinker "$BUILD_DIR"
    fi
    
    # Run the executable
    echo "Running Swift gfx-test..."
    cd "$BUILD_DIR" && ./gfx-test
    
elif [[ "$OSTYPE" == "linux"* ]]; then
    # --- Linux - Run Zig implementation ---
    echo "Detected Linux - Running Zig implementation"
    
    # Ensure we're in the project root directory
    cd "$PROJECT_ROOT"
    echo "Running from directory: $(pwd)"
    
    # Run the Zig code from the root directory
    zig run \
      -lc \
      -lvulkan \
      -lxcb \
      -lstdc++ \
      -I /usr/include/ \
      -I /usr/include/x86_64-linux-gnu \
      -I ./vendor/shaderc/include \
      -L ./vendor/shaderc/build/lib \
      -lshaderc_combined \
      ./src/gfx/linux/main.zig
    
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi