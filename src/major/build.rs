use std::env;
use std::path::Path;
use std::process::Command;

fn zig_target() -> &'static str {
    match &*env::var("TARGET").expect("must be compiled with cargo") {
        "x86_64-pc-windows-msvc" => "x86_64-windows",
        "aarch64-pc-windows-msvc" => "aarch64-windows",
        "x86_64-unknown-linux-gnu" => "x86_64-linux",
        "aarch64-unknown-linux-gnu" => "aarch64-linux",
        "aarch64-apple-darwin" => "aarch64-macos",
        _ => panic!("Unsupported target"),
    }
}

fn zig_optimize() -> &'static str {
    match &*env::var("PROFILE").expect("must be compiled with cargo") {
        "debug" => "Debug",
        "release" => "ReleaseFast",
        _ => panic!("Unsupported profile"),
    }
}

fn main() {
    // let out_dir = env::var("OUT_DIR").unwrap();
    // let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    // println!("cargo:rerun-if-changed=build.zig");
    // println!("cargo:rerun-if-changed=native");

    // let output = Command::new("zig").args(["build", "--prefix", &out_dir, "-Dtarget", zig_target(), "-Doptimize", zig_optimize()])
    //     .current_dir(Path::new(&manifest_dir).join("native"))
    //     .output()
    //     .expect("Failed to run zig build");

    // if !output.status.success() {
    //     eprintln!("Zig build failed with status: {}", output.status);
    //     eprintln!("stdout: {}", String::from_utf8_lossy(&output.stdout));
    //     eprintln!("stderr: {}", String::from_utf8_lossy(&output.stderr));
    //     panic!("Zig build failed");
    // }

    // if !output.stdout.is_empty() {
    //     println!("cargo:warning=Zig build output: {}", String::from_utf8_lossy(&output.stdout));
    // }

    // println!("cargo:rustc-link-search=native={}/lib", out_dir);
}
