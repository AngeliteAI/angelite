use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    // Get the project root directory
    let mut project_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    project_root.pop();
    project_root.pop();
    let project_root = project_root.to_str().unwrap();
    println!("cargo:warning=Project root: {}", project_root);

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

    // Copy the math library to the target directory
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("libmath.a");
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

    let zig_gfx_lib_path = format!("{}/zig-out/lib/libgfx.a", gfx_dir);
    if !Path::new(&zig_gfx_lib_path).exists() {
        panic!("Error: Zig gfx static library build failed or not found.");
    }

    // Copy the gfx library to the target directory
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("libgfx.a");
    let gfx_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_gfx_lib_path, gfx_dest_path).unwrap();

    // Set up linking for both libraries
    println!("cargo:rustc-link-search=native={}", out_dir);
    println!("cargo:rustc-link-lib=static=math");
    println!("cargo:rustc-link-lib=static=gfx");

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
    let build_dir = format!("{}/build", root_dir);

    // Create build directory if it doesn't exist
    std::fs::create_dir_all(&build_dir).unwrap();

    // Build Zig math library with debug symbols
    println!("Building Zig math library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&math_src_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_math_lib_path = format!("{}/zig-out/lib/libmath.a", math_src_dir);

    // Copy the math library to the target directory
    let out_dir = project_root.to_owned() + "/target/debug";
    let dest_path = Path::new(&out_dir).join("libmath.a");
    let lib_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_math_lib_path, lib_dest_path).unwrap();

    if !Path::new(&lib_dest_path).exists() {
        panic!("Error: Zig math static library build failed or not found.");
    }

    // Build Zig gfx library with debug symbols
    println!("Building Zig gfx library with debug symbols...");
    let current_dir = env::current_dir().unwrap();
    env::set_current_dir(&gfx_dir).unwrap();
    run_command("zig", &["build", "-Doptimize=Debug"]);
    env::set_current_dir(current_dir).unwrap();

    let zig_gfx_lib_path = format!("{}/zig-out/lib/libgfx.a", gfx_dir);

    // Copy the gfx library to the target directory
    let dest_path = Path::new(&out_dir).join("libgfx.a");
    let gfx_dest_path = dest_path.to_str().unwrap();
    std::fs::copy(&zig_gfx_lib_path, gfx_dest_path).unwrap();
    if !Path::new(&gfx_dest_path).exists() {
        panic!("Error: Zig gfx static library build failed or not found.");
    }

    // Set up linking for both libraries
    // Verify the library files exist
    println!("cargo:warning=Math library path: {}", lib_dest_path);
    println!("cargo:warning=GFX library path: {}", gfx_dest_path);

    // Tell cargo where to find the libraries
    println!("cargo:rustc-link-search=native={}", out_dir);
    println!("cargo:rustc-link-lib=static=math");
    println!("cargo:rustc-link-lib=static=gfx");

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

    println!("Running zig build command for static library...");
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
    let math_lib_path = format!("{}\\zig-out\\lib\\math.lib", math_src_dir); // CHANGED to .lib
    println!("Math lib path: {}", math_lib_path); // ADDED

    if !Path::new(&math_lib_path).exists() {
        panic!(
            "Error: Math static library not found at {}. Check Zig build configuration.",
            &math_lib_path
        );
    }

    // Get the target directory
    let out_dir = build_dir.clone();
    let dest_path = Path::new(&out_dir).join("math.lib"); // CHANGED to .lib
    let lib_dest_path = dest_path.to_str().unwrap();

    // Copy the static library to the build directory
    std::fs::copy(&math_lib_path, lib_dest_path).unwrap(); // CHANGED to .lib
    println!("Copied math static library to: {}", lib_dest_path);

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

    println!("Running zig build command for gfx static library...");
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
    let gfx_lib_path = format!("{}\\zig-out\\lib\\gfx.lib", gfx_dir); // CHANGED to .lib
    println!("Gfx lib path: {}", gfx_lib_path); // ADDED

    if !Path::new(&gfx_lib_path).exists() {
        panic!(
            "Error: Gfx static library not found at {}. Check Zig build configuration.",
            &gfx_lib_path
        );
    }

    // Get the target directory
    let out_dir = build_dir.clone();
    let dest_path = Path::new(&out_dir).join("gfx.lib"); // CHANGED to .lib
    let gfx_dest_path = dest_path.to_str().unwrap();

    // Copy the gfx static library to the build directory
    std::fs::copy(&gfx_lib_path, gfx_dest_path).unwrap(); // CHANGED to .lib
    println!("Copied gfx static library to: {}", gfx_dest_path);

    println!(
        "Checking if gfx.lib exists at build directory: {}",
        build_dir
    );
    if Path::new(&format!("{}\\gfx.lib", build_dir)).exists() {
        // CHANGED to .lib
        println!("✓ gfx.lib found in build directory");
    } else {
        println!("✗ gfx.lib NOT found in build directory");
    }

    // Add a check to confirm that gfx.lib is in the OUT_DIR
    let out_dir_gfx_lib = Path::new(&out_dir).join("gfx.lib"); // CHANGED to .lib
    if out_dir_gfx_lib.exists() {
        println!("✓ gfx.lib found in OUT_DIR: {}", out_dir);
    } else {
        println!("✗ gfx.lib NOT found in OUT_DIR: {}", out_dir);
    }

    // Make sure we link to our own gfx.lib, not one in the Vulkan SDK
    // Ensure library paths are in the right order (build dir should be first)
    println!("cargo:rustc-link-search=native={}", out_dir);

    // Ensure static linking
    println!("cargo:rustc-link-lib=static=math"); // CHANGED to static
    println!("cargo:rustc-link-lib=static=gfx"); // CHANGED to static

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

    if (!sdk_path.exists()) {
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

    if (!output.status.success()) {
        let stderr = String::from_utf8_lossy(&output.stderr);
        panic!("Command '{}' failed: {}", cmd, stderr);
    }

    String::from_utf8_lossy(&output.stdout).trim().to_string()
}
