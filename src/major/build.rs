use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Only run Swift compilation on macOS
    if cfg!(target_os = "macos") {
        compile_metal_renderer();
    }
}

fn compile_metal_renderer() {
    // Get output directory
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let lib_name = "metal_renderer";

    // Create directory for output if needed
    let lib_dir = out_dir.join("lib");
    fs::create_dir_all(&lib_dir).unwrap();

    // Path to Swift source file
    let swift_file = "src/gfx/metal/Render.swift";

    // Only recompile if the source file changes
    println!("cargo:rerun-if-changed={}", swift_file);

    // Output paths
    let dylib_path = lib_dir.join(format!("lib{}.dylib", lib_name));

    // Compile Swift file
    let status = Command::new("swiftc")
        .args(&[
            "-emit-library",
            swift_file,
            "-o",
            dylib_path.to_str().unwrap(),
            "-module-name",
            lib_name,
            "-framework",
            "Foundation",
            "-framework",
            "Metal",
            "-framework",
            "QuartzCore",
        ])
        .status()
        .expect("Failed to compile Swift file");

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
