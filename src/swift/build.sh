rm HelloTriangle
# First compile the metal shader
cd gfx/src
xcrun -sdk macosx metal -c Shaders.metal -o Shaders.air
xcrun -sdk macosx metallib Shaders.air -o default.metallib
cd ../..

# Then compile Swift with explicit paths
find . -name "*.swift" -print0 | xargs -0 swiftc -parse-as-library -o HelloTriangle -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.2.sdk -I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.2.sdk/usr/include -F/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX15.2.sdk/System/Library/Frameworks -framework Cocoa -framework Metal -framework MetalKit

./HelloTriangle