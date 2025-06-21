use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Only run Swift compilation on macOS
    if cfg!(target_os = "macos") {
        compile_swift_sources();
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
