use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Recursively walks a directory and registers all files for cargo to rerun the build script if they change
fn watch_dir_for_changes(dir: &str) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            let path_str = path.to_str().unwrap_or_default();

            if path.is_file() {
                println!("cargo:rerun-if-changed={}", path_str);
            } else if path.is_dir() {
                watch_dir_for_changes(path_str);
            }
        }
    }
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    // Get the project root directory
    let mut project_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    project_root.pop();
    project_root.pop();
    let project_root = project_root.to_str().unwrap();
    println!("cargo:warning=Project root: {}", project_root);

    // Direct linking to Zig functions - no wrapper needed
    println!("cargo:warning=Using direct linking to Zig functions");

    // Watch Zig dependencies for changes
    let math_dir = format!("{}/src/math", project_root);
    let gfx_dir = format!("{}/src/gfx", project_root);
    let surface_dir = format!("{}/src/surface", project_root);

    println!("cargo:warning=Watching for changes in: {}", math_dir);
    watch_dir_for_changes(&math_dir);

    println!("cargo:warning=Watching for changes in: {}", gfx_dir);
    watch_dir_for_changes(&gfx_dir);

    println!("cargo:warning=Watching for changes in: {}", surface_dir);
    watch_dir_for_changes(&surface_dir);

    // Get and print target information for debugging
    let target = env::var("TARGET").unwrap_or_else(|_| "unknown".to_string());
    let host = env::var("HOST").unwrap_or_else(|_| "unknown".to_string());
    println!("Host platform: {}", host);
    println!("Target platform: {}", target);
    println!("Target OS from env consts: {}", std::env::consts::OS);

    // Detect operating system and set up paths accordingly
    if cfg!(target_os = "macos") {
        build_macos(&project_root);
    } else if cfg!(target_os = "linux") {
        build_linux(&project_root);
    } else if cfg!(target_os = "windows") {
        build_windows(&project_root);
    } else {
        panic!("Unsupported operating system");
    }
}

fn build_macos(project_root: &str) {
    println!("Building for macOS");

    // Set up paths
    let root_dir = project_root;
    let gfx_src_dir = format!("{}/src/gfx/src/macos", root_dir);
    let gfx_dir = format!("{}/src/gfx", root_dir);
    let math_src_dir = format!("{}/src/math/src", root_dir);
    let input_dir = format!("{}/src/input", root_dir);
    let build_dir = format!("{}/build", root_dir);

    // Create build directory if it doesn't exist
    std::fs::create_dir_all(&build_dir).unwrap();

    // Get macOS SDK paths using xcrun
    let osx_sdk_path = get_command_output("xcrun", &["--sdk", "macosx", "--show-sdk-path"]);
    if osx_sdk_path.is_empty() {
        panic!("Error: Could not determine macOS SDK path. Make sure Xcode is installed.");
    }
    let osx_sdk_frameworks_dir = format!("{}/System/Library/Frameworks", osx_sdk_path);

    // Compile Metal shaders if they exist
    let metal_shader_path = format!("{}/Shaders.metal", gfx_src_dir);
    if Path::new(&metal_shader_path).exists() {
        println!("Compiling Shaders.metal with debug symbols...");

        run_command(
            "xcrun",
            &[
                "-sdk",
                "macosx",
                "metal",
                "-c",
                &metal_shader_path,
                "-o",
                &format!("{}/Shaders.air", build_dir),
                "-g",
                "-frecord-sources",
                "-MO",
            ],
        );

        run_command(
            "xcrun",
            &[
                "-sdk",
                "macosx",
                "metallib",
                &format!("{}/Shaders.air", build_dir),
                "-o",
                &format!("{}/default.metallib", build_dir),
            ],
        );
    }

    // Build Zig math library with debug symbols
    println!("Building Zig math library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&math_src_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    // Build Zig surface library with debug symbols
    println!("Building Zig surface library with debug symbols...");
    let surface_src_dir = format!("{}/src/surface", root_dir);
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&surface_src_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_surface_lib_path = format!("{}/zig-out/lib/libsurface.a", surface_src_dir);
    if !Path::new(&zig_surface_lib_path).exists() {
        panic!("Error: Zig surface static library build failed or not found.");
    }

    let zig_math_lib_path = format!("{}/zig-out/lib/libmath.a", math_src_dir);
    if !Path::new(&zig_math_lib_path).exists() {
        panic!("Error: Zig math static library build failed or not found.");
    }

    // Now we expect dylib (.dylib) files instead of static libraries (.a)
    let zig_math_lib_path = format!("{}/zig-out/lib/libmath.dylib", math_src_dir);
    if !Path::new(&zig_math_lib_path).exists() {
        panic!("Error: Zig math shared library not found at {}", zig_math_lib_path);
    }

    // Copy the math library to the target directory
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("libmath.dylib");
    let lib_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_math_lib_path, lib_dest_path).unwrap();

    // Build Zig gfx library with debug symbols
    println!("Building Zig gfx library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&gfx_dir).unwrap();
    run_command(
        "zig",
        &["build", "-Doptimize=Debug", "-DMIDL_INTERFACE=struct"],
    );
    env::set_current_dir(current_dir).unwrap();

    let zig_gfx_lib_path = format!("{}/zig-out/lib/libgfx.dylib", gfx_dir);
    if !Path::new(&zig_gfx_lib_path).exists() {
        panic!("Error: Zig gfx shared library build failed or not found.");
    }

    // Copy the gfx library to the target directory
    let dest_path = Path::new(&out_dir).join("libgfx.dylib");
    let gfx_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_gfx_lib_path, gfx_dest_path).unwrap();

    // Build Zig input library with debug symbols
    println!("Building Zig input library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&input_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_input_lib_path = format!("{}/zig-out/lib/libinput.dylib", input_dir);
    if !Path::new(&zig_input_lib_path).exists() {
        panic!("Error: Zig input shared library build failed or not found.");
    }

    // Copy the input library to the target directory
    let dest_path = Path::new(&out_dir).join("libinput.dylib");
    let input_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_input_lib_path, input_dest_path).unwrap();

    // Set up linking for all libraries - now using dylib instead of static
    println!("cargo:rustc-link-search=native={}", out_dir);
    println!("cargo:rustc-link-lib=dylib=math");
    println!("cargo:rustc-link-lib=dylib=gfx");
    println!("cargo:rustc-link-lib=dylib=input");

    // Link to macOS frameworks
    println!(
        "cargo:rustc-link-search=framework={}",
        osx_sdk_frameworks_dir
    );
    println!("cargo:rustc-link-lib=framework=Cocoa");
    println!("cargo:rustc-link-lib=framework=Metal");
    println!("cargo:rustc-link-lib=framework=MetalKit");

    // Set rpath
    println!("cargo:rustc-link-arg=-Wl,-rpath,@executable_path");
    println!("cargo:rustc-link-arg=-Wl,-rpath,{}", build_dir);
}

fn build_linux(project_root: &str) {
    println!("Building for Linux");

    // Set up paths
    let root_dir = project_root;
    let math_src_dir = format!("{}/src/math/", root_dir);
    let gfx_dir = format!("{}/src/gfx", root_dir);
    let input_dir = format!("{}/src/input", root_dir);
    let build_dir = format!("{}/build", root_dir);

    // Create build directory if it doesn't exist
    std::fs::create_dir_all(&build_dir).unwrap();

    // Build Zig math library with debug symbols
    println!("Building Zig math library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&math_src_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_math_lib_path = format!("{}/zig-out/lib/libmath.so", math_src_dir);
    if !Path::new(&zig_math_lib_path).exists() {
        panic!("Error: Zig math shared library not found at {}", zig_math_lib_path);
    }

    // Copy the math library to the target directory
    let out_dir = project_root.to_owned() + "/target/debug";
    let dest_path = Path::new(&out_dir).join("libmath.so");
    let lib_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_math_lib_path, lib_dest_path).unwrap();

    if !Path::new(&lib_dest_path).exists() {
        panic!("Error: Zig math shared library build failed or not found.");
    }

    // Build Zig gfx library with debug symbols
    println!("Building Zig gfx library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&gfx_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_gfx_lib_path = format!("{}/zig-out/lib/libgfx.so", gfx_dir);
    if !Path::new(&zig_gfx_lib_path).exists() {
        panic!("Error: Zig gfx shared library not found at {}", zig_gfx_lib_path);
    }

    // Copy the gfx library to the target directory
    let dest_path = Path::new(&out_dir).join("libgfx.so");
    let gfx_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_gfx_lib_path, gfx_dest_path).unwrap();
    if !Path::new(&gfx_dest_path).exists() {
        panic!("Error: Zig gfx shared library build failed or not found.");
    }

    // Set up linking for both libraries
    // Verify the library files exist
    println!("cargo:warning=Math library path: {}", lib_dest_path);
    println!("cargo:warning=GFX library path: {}", gfx_dest_path);

    // Tell cargo where to find the libraries
    println!("cargo:rustc-link-search=native={}", out_dir);
    println!("cargo:rustc-link-lib=dylib=math");
    println!("cargo:rustc-link-lib=dylib=gfx");

    // Build Zig input library with debug symbols
    println!("Building Zig input library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&input_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_input_lib_path = format!("{}/zig-out/lib/libinput.so", input_dir);
    if !Path::new(&zig_input_lib_path).exists() {
        panic!("Error: Zig input shared library not found at {}", zig_input_lib_path);
    }

    // Copy the input library to the target directory
    let dest_path = Path::new(&out_dir).join("libinput.so");
    let input_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_input_lib_path, input_dest_path).unwrap();
    if !Path::new(&input_dest_path).exists() {
        panic!("Error: Zig input shared library build failed or not found.");
    }

    // Add input library to link list
    println!("cargo:rustc-link-lib=dylib=input");
    
    // Set LD_LIBRARY_PATH so the shared libraries can be found at runtime
    println!("cargo:rustc-env=LD_LIBRARY_PATH={}", out_dir);

    // Additional Linux-specific libraries
    // Link to Vulkan
    println!("cargo:rustc-link-lib=vulkan");

    // Link to XCB and related libraries
    println!("cargo:rustc-link-lib=xcb");
    println!("cargo:rustc-link-lib=X11");
    println!("cargo:rustc-link-lib=X11-xcb");

    // Print message about dependencies
    println!("Note: Make sure you have Vulkan and XCB development packages installed.");
    println!(
        "On Ubuntu/Debian: sudo apt-get install libvulkan-dev libxcb-dri3-dev libx11-dev libx11-xcb-dev libxcb1-dev"
    );
    println!(
        "On Fedora: sudo dnf install vulkan-devel libxcb-devel libX11-devel libX11-xcb libxcb-devel"
    );
}

fn build_windows(project_root: &str) {
    println!("Building for Windows");

    // Set up paths
    let root_dir = project_root;
    let math_src_dir = format!("{}/src/math", root_dir);
    let gfx_dir = format!("{}/src/gfx", root_dir);
    let input_dir = format!("{}/src/input", root_dir);
    let build_dir = format!("{}/target/debug", root_dir);

    // Build Zig math library
    println!("Building Zig math library...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&math_src_dir).unwrap();

    // Check if zig is in PATH and get version info
    let zig_version = Command::new("zig").arg("help").output();
    match zig_version {
        Ok(output) => {
            if output.status.success() {
                println!("Zig working");
            } else {
                println!(
                    "Zig found but command check failed: {}",
                    String::from_utf8_lossy(&output.stderr).trim()
                );
            }
        }
        Err(_) => {
            panic!(
                "Error: Zig compiler not found in PATH. Please install Zig or add it to your PATH."
            );
        }
    }

    // Check if build.zig exists
    let build_zig_path = format!("{}\\build.zig", math_src_dir);
    if !Path::new(&build_zig_path).exists() {
        panic!(
            "Error: build.zig not found at {}. Please ensure the math project is properly set up.",
            build_zig_path
        );
    }

    println!("Running zig build command for shared library...");
    // Run standard zig build command with explicit MSVC target
    let build_result = Command::new("zig")
        .args(&[
            "build",
            "-Dtarget=x86_64-windows-msvc",
            "-Doptimize=Debug",
            "-freference-trace",
        ]) // Explicitly specify MSVC target
        .current_dir(&math_src_dir)
        .output();

    match build_result {
        Ok(output) => {
            println!(
                "Zig build stdout: {}",
                String::from_utf8_lossy(&output.stdout)
            );
            println!(
                "Zig build stderr: {}",
                String::from_utf8_lossy(&output.stderr)
            );
            if !output.status.success() {
                panic!(
                    "Zig build failed with error: {}",
                    String::from_utf8_lossy(&output.stderr)
                );
            }
        }
        Err(e) => {
            panic!("Failed to execute zig build: {}", e);
        }
    }

    env::set_current_dir(current_dir).unwrap();

    // Windows paths with backslashes need to be handled carefully
    // For shared libraries on Windows, we need both the DLL and its import lib
    let math_dll_path = format!("{}\\zig-out\\bin\\math.dll", math_src_dir);
    let math_lib_path = format!("{}\\zig-out\\lib\\math.lib", math_src_dir); // Import lib
    println!("Math DLL path: {}", math_dll_path);
    println!("Math import lib path: {}", math_lib_path);

    if !Path::new(&math_dll_path).exists() {
        panic!(
            "Error: Math shared library (DLL) not found at {}. Check Zig build configuration.",
            &math_dll_path
        );
    }

    if !Path::new(&math_lib_path).exists() {
        panic!(
            "Error: Math import library not found at {}. Check Zig build configuration.",
            &math_lib_path
        );
    }

    // Get the target directory
    let out_dir = build_dir.clone();
    
    // Copy both DLL and import library to the build directory
    let dll_dest_path = Path::new(&out_dir).join("math.dll");
    let dll_dest_path_str = dll_dest_path.to_str().unwrap();
    std::fs::copy(&math_dll_path, dll_dest_path_str).unwrap();
    println!("Copied math DLL to: {}", dll_dest_path_str);
    
    let lib_dest_path = Path::new(&out_dir).join("math.lib");
    let lib_dest_path_str = lib_dest_path.to_str().unwrap();
    std::fs::copy(&math_lib_path, lib_dest_path_str).unwrap();
    println!("Copied math import library to: {}", lib_dest_path_str);

    // Build Zig gfx library
    println!("Building Zig gfx library...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&gfx_dir).unwrap();

    // Check if build.zig exists for gfx
    let build_gfx_zig_path = format!("{}\\build.zig", gfx_dir);
    if !Path::new(&build_gfx_zig_path).exists() {
        panic!(
            "Error: build.zig not found at {}. Please ensure the gfx project is properly set up.",
            build_gfx_zig_path
        );
    }

    println!("Running zig build command for gfx shared library...");
    let build_result = Command::new("zig")
        .args(&[
            "build",
            "-Dtarget=x86_64-windows-msvc",
            "-Doptimize=Debug",
            "-freference-trace",
        ]) // Explicitly specify MSVC target
        .current_dir(&gfx_dir)
        .output();

    match build_result {
        Ok(output) => {
            println!(
                "Zig build for gfx stdout: {}",
                String::from_utf8_lossy(&output.stdout)
            );
            println!(
                "Zig build stderr: {}",
                String::from_utf8_lossy(&output.stderr)
            );
            if !output.status.success() {
                panic!(
                    "Zig build failed with error: {}",
                    String::from_utf8_lossy(&output.stderr)
                );
            }
        }
        Err(e) => {
            panic!("Failed to execute zig build for gfx: {}", e);
        }
    }

    env::set_current_dir(current_dir).unwrap();

    // Windows paths with backslashes need to be handled carefully
    // For shared libraries on Windows, we need both the DLL and its import lib
    let gfx_dll_path = format!("{}\\zig-out\\bin\\gfx.dll", gfx_dir);
    let gfx_lib_path = format!("{}\\zig-out\\lib\\gfx.lib", gfx_dir); // Import lib
    println!("GFX DLL path: {}", gfx_dll_path);
    println!("GFX import lib path: {}", gfx_lib_path);

    if !Path::new(&gfx_dll_path).exists() {
        panic!(
            "Error: GFX shared library (DLL) not found at {}. Check Zig build configuration.",
            &gfx_dll_path
        );
    }

    if !Path::new(&gfx_lib_path).exists() {
        panic!(
            "Error: GFX import library not found at {}. Check Zig build configuration.",
            &gfx_lib_path
        );
    }

    // Get the target directory
    let out_dir = build_dir.clone();
    
    // Copy both DLL and import library to the build directory
    let dll_dest_path = Path::new(&out_dir).join("gfx.dll");
    let dll_dest_path_str = dll_dest_path.to_str().unwrap();
    std::fs::copy(&gfx_dll_path, dll_dest_path_str).unwrap();
    println!("Copied gfx DLL to: {}", dll_dest_path_str);
    
    let lib_dest_path = Path::new(&out_dir).join("gfx.lib");
    let gfx_dest_path = lib_dest_path.to_str().unwrap();
    std::fs::copy(&gfx_lib_path, gfx_dest_path).unwrap();
    println!("Copied gfx import library to: {}", gfx_dest_path);

    println!(
        "Checking if gfx.dll and gfx.lib exist at build directory: {}",
        build_dir
    );
    if Path::new(&format!("{}\\gfx.dll", build_dir)).exists() {
        println!("✓ gfx.dll found in build directory");
    } else {
        println!("✗ gfx.dll NOT found in build directory");
    }
    
    if Path::new(&format!("{}\\gfx.lib", build_dir)).exists() {
        println!("✓ gfx.lib (import library) found in build directory");
    } else {
        println!("✗ gfx.lib (import library) NOT found in build directory");
    }

    // Add a check to confirm that gfx.dll and gfx.lib are in the OUT_DIR
    let out_dir_gfx_dll = Path::new(&out_dir).join("gfx.dll");
    let out_dir_gfx_lib = Path::new(&out_dir).join("gfx.lib");
    if out_dir_gfx_dll.exists() {
        println!("✓ gfx.dll found in OUT_DIR: {}", out_dir);
    } else {
        println!("✗ gfx.dll NOT found in OUT_DIR: {}", out_dir);
    }
    if out_dir_gfx_lib.exists() {
        println!("✓ gfx.lib (import library) found in OUT_DIR: {}", out_dir);
    } else {
        println!("✗ gfx.lib (import library) NOT found in OUT_DIR: {}", out_dir);
    }

    // Build Zig input library
    println!("Building Zig input library...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&input_dir).unwrap();

    // Check if build.zig exists for input
    let build_input_zig_path = format!("{}\\build.zig", input_dir);
    if !Path::new(&build_input_zig_path).exists() {
        panic!(
            "Error: build.zig not found at {}. Please ensure the input project is properly set up.",
            build_input_zig_path
        );
    }

    println!("Running zig build command for input shared library...");
    let build_result = Command::new("zig")
        .args(&[
            "build",
            "-Dtarget=x86_64-windows-msvc",
            "-Doptimize=Debug",
            "-freference-trace",
        ])
        .current_dir(&input_dir)
        .output();

    match build_result {
        Ok(output) => {
            println!(
                "Zig build for input stdout: {}",
                String::from_utf8_lossy(&output.stdout)
            );
            println!(
                "Zig build stderr: {}",
                String::from_utf8_lossy(&output.stderr)
            );
            if !output.status.success() {
                panic!(
                    "Zig build failed with error: {}",
                    String::from_utf8_lossy(&output.stderr)
                );
            }
        }
        Err(e) => {
            panic!("Failed to execute zig build for input: {}", e);
        }
    }

    env::set_current_dir(current_dir).unwrap();

    // Windows paths with backslashes need to be handled carefully
    // For shared libraries on Windows, we need both the DLL and its import lib
    let input_dll_path = format!("{}\\zig-out\\bin\\input.dll", input_dir);
    let input_lib_path = format!("{}\\zig-out\\lib\\input.lib", input_dir); // Import lib
    println!("Input DLL path: {}", input_dll_path);
    println!("Input import lib path: {}", input_lib_path);

    if !Path::new(&input_dll_path).exists() {
        panic!(
            "Error: Input shared library (DLL) not found at {}. Check Zig build configuration.",
            &input_dll_path
        );
    }

    if !Path::new(&input_lib_path).exists() {
        panic!(
            "Error: Input import library not found at {}. Check Zig build configuration.",
            &input_lib_path
        );
    }

    // Get the target directory
    let out_dir = build_dir.clone();
    
    // Copy both DLL and import library to the build directory
    let dll_dest_path = Path::new(&out_dir).join("input.dll");
    let dll_dest_path_str = dll_dest_path.to_str().unwrap();
    std::fs::copy(&input_dll_path, dll_dest_path_str).unwrap();
    println!("Copied input DLL to: {}", dll_dest_path_str);
    
    let lib_dest_path = Path::new(&out_dir).join("input.lib");
    let input_dest_path = lib_dest_path.to_str().unwrap();
    std::fs::copy(&input_lib_path, input_dest_path).unwrap();
    println!("Copied input import library to: {}", input_dest_path);

    // Make sure we link to our own gfx.lib, not one in the Vulkan SDK
    // Ensure library paths are in the right order (build dir should be first)
    println!("cargo:rustc-link-search=native={}", out_dir);

    // Also add project root directory to search paths
    println!("cargo:rustc-link-search=native={}", root_dir);
    println!("cargo:rustc-link-search=native={}/target/debug", root_dir);
    println!(
        "cargo:rustc-link-search=native={}/src/gfx/zig-out/lib",
        root_dir
    );

    // Verify the exact names of the library files before linking

    // Use dynamic linking with explicit library names based on platform
    if cfg!(target_os = "windows") {
        // On Windows, we need to link to the import libraries (.lib) for our DLLs
        println!("cargo:rustc-link-lib=dylib=math");
        println!("cargo:rustc-link-lib=dylib=gfx");
        println!("cargo:rustc-link-lib=dylib=input");
        
        // Set PATH environment variable so the DLLs can be found at runtime
        println!("cargo:rustc-env=PATH={};", out_dir);
    } else {
        // On Unix, we also use dynamic linking
        println!("cargo:rustc-link-lib=dylib=math");
        println!("cargo:rustc-link-lib=dylib=gfx");
        println!("cargo:rustc-link-lib=dylib=input");
    }

    let vulkan_sdk = env::var("VULKAN_SDK").unwrap_or_else(|_| String::new());

    // Make sure the Vulkan library search paths come *after* your own library paths
    if !vulkan_sdk.is_empty() {
        println!("cargo:rustc-link-search={}", format!("{}\\Lib", vulkan_sdk));
        // Explicitly specify dynamic linking for Vulkan
        println!("cargo:rustc-link-lib=dylib=vulkan-1");
    } else {
        // Just ensure we're explicit about dynamic linking
        println!("cargo:rustc-link-lib=dylib=vulkan-1");
    }

    // Add explicit linking to vulkan-1.lib
    if !vulkan_sdk.is_empty() {
        let vulkan_lib_path = format!("{}\\Lib\\vulkan-1.lib", vulkan_sdk);
        if Path::new(&vulkan_lib_path).exists() {
            println!("Linking against Vulkan library: {}", vulkan_lib_path);
        } else {
            println!("Vulkan library not found at: {}", vulkan_lib_path);
        }
    }

    // Link Windows-specific libraries
    if Path::new("C:\\Program Files (x86)\\Windows Kits\\10\\Lib").exists() {
        // Find the newest Windows 10 SDK
        let sdk_lib_dir = find_latest_windows_sdk();
        if !sdk_lib_dir.is_empty() {
            println!("Found Windows 10 SDK: {}", sdk_lib_dir);
            println!("cargo:rustc-link-search=native={}", sdk_lib_dir);
        }
    }

    // Link core Windows libraries
    println!("cargo:rustc-link-lib=user32");
    println!("cargo:rustc-link-lib=gdi32");
    println!("cargo:rustc-link-lib=shell32");
    println!("cargo:rustc-link-lib=ntdll"); // Native NT API functions
    println!("cargo:rustc-link-lib=kernel32");

    // Disable LTO which can cause issues with system libraries
    println!("cargo:rustc-link-arg=/LTCG:OFF");

    // Notify about specific exported symbols we need
    println!("cargo:warning=Looking for the following symbols: init, setCamera, render, shutdown");

    // On Windows, we need to ensure proper linkage with Zig libraries
    if cfg!(target_os = "windows") {
        // Use a specific linking mode for Windows
        println!("cargo:rustc-link-arg=/WHOLEARCHIVE:gfx.lib");

        // Try different name variations since Zig exports functions within a namespace
        // Try bare names
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:init");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:shutdown");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:render");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:setCamera");

        // Try with render_ namespace prefix (from lib.zig)
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:render_init");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:render_shutdown");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:render_render");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:render_setCamera");

        // Try with underscore prefixes (common in Windows ABI)
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_init");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_shutdown");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_render");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_setCamera");

        // Try with both render_ prefix and underscore
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_render_init");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_render_shutdown");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_render_render");
        println!("cargo:rustc-cdylib-link-arg=/EXPORT:_render_setCamera");

        // Add Windows subsystem - use console for debugging
        println!("cargo:rustc-link-arg=/SUBSYSTEM:CONSOLE");

        // Export all symbols from the Zig libraries
        println!("cargo:rustc-link-arg=/VERBOSE");
    }

    // Note about Vulkan on Windows
    println!("Note: Make sure you have the Vulkan SDK installed for Windows.");
    println!("You can download it from https://vulkan.lunarg.com/sdk/home#windows");

    // Remove environment variable for dynamic library loading
    println!("cargo:rustc-env=DYLD_LIBRARY_PATH=");
}

// Helper function to find the latest Windows 10 SDK
fn find_latest_windows_sdk() -> String {
    let sdk_base = "C:\\Program Files (x86)\\Windows Kits\\10\\Lib";
    let sdk_path = Path::new(sdk_base);

    if !sdk_path.exists() {
        return String::new();
    }

    // Try to find the latest version by looking at directory names
    let entries = match std::fs::read_dir(sdk_path) {
        Ok(entries) => entries,
        Err(_) => return String::new(),
    };

    // Collect valid version directories and sort them
    let mut versions: Vec<String> = entries
        .filter_map(|entry| {
            if let Ok(entry) = entry {
                let path = entry.path();
                if path.is_dir() {
                    if let Some(name) = path.file_name() {
                        if let Some(name_str) = name.to_str() {
                            // Filter for version-like directories (10.0.xxxxx.x)
                            if name_str.starts_with("10.") {
                                return Some(name_str.to_string());
                            }
                        }
                    }
                }
            }
            None
        })
        .collect();

    // Sort versions semantically (e.g., 10.0.19041.0 comes after 10.0.18362.0)
    versions.sort_by(|a, b| {
        let a_parts: Vec<u32> = a.split('.').filter_map(|s| s.parse::<u32>().ok()).collect();
        let b_parts: Vec<u32> = b.split('.').filter_map(|s| s.parse::<u32>().ok()).collect();

        // Compare each segment of the version
        for (a_part, b_part) in a_parts.iter().zip(b_parts.iter()) {
            match a_part.cmp(b_part) {
                std::cmp::Ordering::Equal => continue,
                other => return other,
            }
        }
        // If we get here, one version might be a prefix of the other
        a_parts.len().cmp(&b_parts.len())
    });

    // Get the latest (last) version and construct the x64 lib path
    if let Some(latest) = versions.last() {
        return format!("{}\\{}\\um\\x64", sdk_base, latest);
    }

    String::new()
}

fn run_command(cmd: &str, args: &[&str]) {
    let status = Command::new(cmd)
        .args(args)
        .status()
        .unwrap_or_else(|e| panic!("Failed to run {}: {}", cmd, e));

    if !status.success() {
        panic!("Command '{}' failed with exit code: {}", cmd, status);
    }
}

fn get_command_output(cmd: &str, args: &[&str]) -> String {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .unwrap_or_else(|e| panic!("Failed to run {}: {}", cmd, e));

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        panic!("Command '{}' failed: {}", cmd, stderr);
    }

    String::from_utf8_lossy(&output.stdout).trim().to_string()
}
