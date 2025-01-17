use std::{env, path::PathBuf, process::Command};

fn main() {
    #[cfg(target_os = "macos")]
    macos();
}

#[cfg(target_os = "macos")]
fn macos() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let target_dir = manifest_dir.join("target");

    println!("cargo:warning=Building Swift library...");
    println!("cargo:warning=Target dir: {}", target_dir.display());

    std::fs::create_dir_all(&target_dir).unwrap();
    let dylib_path = target_dir.join("libeditor.dylib");

    // Compile Swift code with additional flags for symbol export
    let output = Command::new("swiftc")
        .args([
            "-v",
            "src/macos/main.swift",
            "-emit-library",
            "-emit-module",
            "-parse-as-library",
            "-module-name",
            "Editor",
            "-enable-library-evolution", // Add ABI stability
            "-Xlinker",
            "-exported_symbols_list", // Explicitly export symbols
            "-o",
            dylib_path.to_str().unwrap(),
            "-import-objc-header",
            "src/macos/bridge.h",
            "-framework",
            "Cocoa",
        ])
        .current_dir(&manifest_dir)
        .output()
        .expect("Failed to build Swift code");

    println!(
        "cargo:warning=Compiler stdout: {}",
        String::from_utf8_lossy(&output.stdout)
    );
    println!(
        "cargo:warning=Compiler stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    assert!(output.status.success(), "Swift compilation failed");
    assert!(dylib_path.exists(), "Library file not created!");

    // Verify symbols
    let nm_output = Command::new("nm")
        .arg("-gU") // Show only external symbols
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

    println!("cargo:rerun-if-changed=src/macos/main.swift");
    println!("cargo:rerun-if-changed=src/macos/bridge.h");
}
