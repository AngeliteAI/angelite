use std::{env, path::PathBuf, process::Command};

fn main() {
    #[cfg(target_os = "macos")]
    macos();
}

#[cfg(target_os = "macos")]
fn macos() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let target_dir = manifest_dir.join("../../target");

    println!("cargo:warning=Building Swift library...");
    println!("cargo:warning=Target dir: {}", target_dir.display());

    std::fs::create_dir_all(&target_dir).unwrap();

    // Create exports list
    let exports_path = target_dir.join("exports.list");
    std::fs::write(&exports_path, "_editor_start\n").unwrap();

    // Compile Swift code
    let output = Command::new("swiftc")
        .args([
            "-v",
            "src/macos/main.swift",
            "-emit-library",
            "-emit-module",
            "-parse-as-library",
            "-module-name",
            "Editor",
            "-module-link-name",
            "editor",
            "-enable-library-evolution",
            "-Xlinker",
            "-exported_symbols_list",
            "-Xlinker",
            exports_path.to_str().unwrap(),
            "-o",
            target_dir.join("libeditor.dylib").to_str().unwrap(),
            "-import-objc-header",
            "src/macos/bridge.h",
            "-Xcc",
            "-fmodule-map-file=src/macos/module.modulemap",
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

    // Copy module map to target dir for external consumers
    std::fs::copy(
        manifest_dir.join("src/macos/module.modulemap"),
        target_dir.join("module.modulemap"),
    )
    .unwrap();

    // Link configuration
    println!("cargo:rustc-link-search=native={}", target_dir.display());
    println!("cargo:rustc-link-lib=dylib=editor");
    println!("cargo:rustc-link-lib=framework=Cocoa");

    // Rerun if sources change
    println!("cargo:rerun-if-changed=src/macos/main.swift");
    println!("cargo:rerun-if-changed=src/macos/bridge.h");
    println!("cargo:rerun-if-changed=src/macos/module.modulemap");
}
