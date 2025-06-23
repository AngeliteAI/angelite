use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    if cfg!(target_os = "macos") {
        // Run Swift compilation on macOS
        compile_swift_sources();
    } else if cfg!(target_os = "windows") {
        // Run Zig compilation to build a single binary for Windows
        compile_windows_binary();
    }
}

fn compile_swift_sources() {
    // Get output directory
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let lib_name = "angelite_swift";

    // Create directory for output if needed
    let lib_dir = out_dir.join("lib");
    fs::create_dir_all(&lib_dir).unwrap();

    // Define all Swift source files
    let swift_files = [
        "src/surface/macos/Surface.swift", // This must be first for dependency reasons
        "src/gfx/metal/Render.swift",
        "src/engine/mac/Engine.swift",
        "src/controller/macos/Controller.swift",
    ];

    // Only recompile if any source file changes
    for swift_file in &swift_files {
        println!("cargo:rerun-if-changed={}", swift_file);
    }

    // Output paths
    let dylib_path = lib_dir.join(format!("lib{}.dylib", lib_name));

    // Compile Swift files
    let mut command = Command::new("swiftc");
    command.arg("-emit-library");
    command.arg("-emit-module");
    command.arg("-module-name");
    command.arg(lib_name);
    command.arg("-parse-as-library");
    command.arg("-v"); // Add verbose flag for better error reporting
    command.arg("-Xfrontend");
    command.arg("-debug-time-function-bodies");

    // Add all source files
    for file in &swift_files {
        command.arg(file);
    }

    // Output file
    command.arg("-o");
    command.arg(dylib_path.to_str().unwrap());

    // Add frameworks
    command.arg("-framework").arg("Foundation");
    command.arg("-framework").arg("Metal");
    command.arg("-framework").arg("QuartzCore");
    command.arg("-framework").arg("AppKit");
    command.arg("-framework").arg("GameController");

    // Execute the compiler
    println!("Swift compilation command: {:?}", command);

    let status = command.status().expect("Failed to compile Swift files");

    if !status.success() {
        panic!("Swift compilation failed");
    }

    // Link against our Swift library
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=dylib={}", lib_name);

    // Link against standard Swift libraries
    for lib in &[
        "swiftCore",
        "swiftFoundation",
        "swiftMetal",
        "swiftQuartzCore",
        "swiftAppKit",
        "swiftDarwin",
    ] {
        println!("cargo:rustc-link-lib=dylib={}", lib);
    }

    // Add Swift runtime library search paths
    let sdk_path = Command::new("xcrun")
        .args(&["--show-sdk-path"])
        .output()
        .ok()
        .and_then(|output| {
            if output.status.success() {
                Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_default();

    if !sdk_path.is_empty() {
        println!("cargo:rustc-link-search=native={}/usr/lib/swift", sdk_path);
    }

    println!("cargo:rustc-link-search=native=/usr/lib/swift");
}

fn compile_windows_binary() {
    // Get output directory
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let lib_name = "angelite_windows";

    // Create a temporary directory for compilation
    let temp_dir = out_dir.join("zig_temp");
    fs::create_dir_all(&temp_dir).unwrap();

    println!("Output directory: {}", out_dir.display());
    println!("Temp directory: {}", temp_dir.display());

    // Get absolute path to the target directory
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let profile = env::var("PROFILE").unwrap();
    let target_dir = PathBuf::from(&manifest_dir)
        .join("..")
        .join("..")
        .join("target")
        .join(&profile);
    println!("Target directory: {}", target_dir.display());

    // Only recompile if any source file or build script changes
    println!("cargo:rerun-if-changed=build.zig");
    println!("cargo:rerun-if-changed=build.zig.zon");
    println!("cargo:rerun-if-changed=src/**/*.zig");
    println!("cargo:rerun-if-changed=src/gfx/vk/*.zig");

    // Create temp src directory structure
    let temp_src_dir = temp_dir.join("src");
    fs::create_dir_all(&temp_src_dir).unwrap();

    // Copy all Zig files from src to temp/src
    let src_dir = PathBuf::from("src");
    copy_dir_recursively(&src_dir, &temp_src_dir).expect("Failed to copy source files");

    // Copy the build.zig file to the temp directory
    let build_zig_path = PathBuf::from("build.zig");
    let temp_build_zig_path = temp_dir.join("build.zig");

    println!(
        "Copying build file: {} -> {}",
        build_zig_path.display(),
        temp_build_zig_path.display()
    );
    fs::copy(&build_zig_path, &temp_build_zig_path).expect("Failed to copy build.zig file");

    // Copy the build.zig.zon file to the temp directory
    let build_zig_zon_path = PathBuf::from("build.zig.zon");
    let temp_build_zig_zon_path = temp_dir.join("build.zig.zon");

    println!(
        "Copying build.zig.zon file: {} -> {}",
        build_zig_zon_path.display(),
        temp_build_zig_zon_path.display()
    );
    fs::copy(&build_zig_zon_path, &temp_build_zig_zon_path)
        .expect("Failed to copy build.zig.zon file");

    // Copy or symlink the vendor directory to the temp directory
    let vendor_path = PathBuf::from("../../vendor");
    let temp_vendor_path = temp_dir.join("vendor");

    // Fall back to copying on other platforms
    copy_dir_recursively(&vendor_path, &temp_vendor_path).expect("Failed to copy vendor directory");

    // Run zig build command
    println!("Running zig build...");
    let status = Command::new("zig")
        .args(["build"])
        .current_dir(&temp_dir)
        .status()
        .expect("Failed to execute zig build command");

    if !status.success() {
        panic!("Zig compilation failed with status: {}", status);
    }

    // Copy the DLL and LIB files from zig-out/bin to the output directory
    let source_dll = temp_dir
        .join("zig-out/bin")
        .join(format!("{}.dll", lib_name));
    let source_lib = temp_dir
        .join("zig-out/lib")
        .join(format!("{}.lib", lib_name));

    let output_dll = out_dir.join(format!("{}.dll", lib_name));
    let output_lib = out_dir.join(format!("{}.lib", lib_name));

    println!(
        "Copying {} -> {}",
        source_dll.display(),
        output_dll.display()
    );
    fs::copy(&source_dll, &output_dll).expect("Failed to copy DLL file");

    println!(
        "Copying {} -> {}",
        source_lib.display(),
        output_lib.display()
    );
    fs::copy(&source_lib, &output_lib).expect("Failed to copy LIB file");

    // Copy the DLL to the target directory where the executable can find it
    let target_dll = target_dir.join(format!("{}.dll", lib_name));
    println!(
        "Copying {} -> {}",
        source_dll.display(),
        target_dll.display()
    );
    fs::copy(&source_dll, &target_dll).expect("Failed to copy DLL to target directory");

    // Helper function to recursively copy directories
    fn copy_dir_recursively(source: &PathBuf, destination: &PathBuf) -> std::io::Result<()> {
        if !source.is_dir() {
            return Ok(());
        }

        if !destination.exists() {
            fs::create_dir_all(destination)?;
        }

        for entry in fs::read_dir(source)? {
            let entry = entry?;
            let entry_path = entry.path();
            let file_name = entry.file_name();
            let dest_path = destination.join(file_name);

            if entry_path.is_dir() {
                copy_dir_recursively(&entry_path, &dest_path)?;
            } else {
                // Copy all files in vendor directory, but for others only copy .zig files
                let should_copy = if source.to_string_lossy().contains("vendor") {
                    true
                } else if let Some(ext) = entry_path.extension() {
                    ext == "zig"
                } else {
                    false
                };

                if should_copy {
                    // Create parent directories if they don't exist
                    if let Some(parent) = dest_path.parent() {
                        if !parent.exists() {
                            fs::create_dir_all(parent)?;
                        }
                    }

                    println!(
                        "Copying: {} -> {}",
                        entry_path.display(),
                        dest_path.display()
                    );
                    fs::copy(&entry_path, &dest_path)?;
                }
            }
        }

        Ok(())
    }

    // Link against our library
    println!("cargo:rustc-link-search=native={}", out_dir.display());
    println!("cargo:rustc-link-lib=dylib={}", lib_name);

    // Link against Windows libraries
    println!("cargo:rustc-link-lib=dylib=user32");
    println!("cargo:rustc-link-lib=dylib=gdi32");
    println!("cargo:rustc-link-lib=dylib=kernel32");
}
