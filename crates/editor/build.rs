use std::{env, path::PathBuf, process::Command};

fn main() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let target_dir = manifest_dir.join("target");

    // Print debugging information
    println!("cargo:warning=Building Swift library...");
    println!("cargo:warning=Output dir: {}", out_dir.display());
    println!("cargo:warning=Target dir: {}", target_dir.display());

    // Ensure output directories exist
    std::fs::create_dir_all(&target_dir).unwrap();

    let dylib_path = target_dir.join("libeditor.dylib");

    // Compile Swift code with verbose output
    let output = Command::new("swiftc")
        .args([
            "-v", // Add verbose flag
            "src/macos/main.swift",
            "-emit-library",
            "-o",
            dylib_path.to_str().unwrap(),
            "-import-objc-header",
            "src/macos/bridge.h",
            "-framework",
            "Cocoa",
        ])
        .output()
        .expect("Failed to build Swift code");

    // Print compilation output
    println!(
        "cargo:warning=Compiler stdout: {}",
        String::from_utf8_lossy(&output.stdout)
    );
    println!(
        "cargo:warning=Compiler stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    assert!(output.status.success());

    // Verify the library exists
    assert!(dylib_path.exists(), "Library file not created!");

    // Run nm to verify symbols
    let nm_output = Command::new("nm")
        .arg(&dylib_path)
        .output()
        .expect("Failed to run nm");

    println!(
        "cargo:warning=Library symbols:\n{}",
        String::from_utf8_lossy(&nm_output.stdout)
    );

    // Link against the generated dylib
    println!("cargo:rustc-link-search=native={}", target_dir.display());
    println!("cargo:rustc-link-lib=dylib=editor");
    println!("cargo:rustc-link-search=framework=/System/Library/Frameworks");
    println!("cargo:rustc-link-lib=framework=Cocoa");

    // Ensure rebuilding when Swift files change
    println!("cargo:rerun-if-changed=src/macos/main.swift");
    println!("cargo:rerun-if-changed=src/macos/bridge.h");
}
