use regex::Regex;
use std::{env, fs, io::Write, path::PathBuf, process::Command};

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let target_dir = manifest_dir.join("../../../target"); // Centralized target
    let profile = env::var("PROFILE").unwrap_or_else(|_| "debug".to_string()); // Get build profile
    // Build Zig library on all platforms
    build_zig_library(&manifest_dir, &target_dir, &profile);
    build_ffi(&manifest_dir);
}

fn build_ffi(manifest_dir: &PathBuf) {
    // Collect all Zig headers and prepare the input for the Python script
    let paths = collect_zig_headers_for_binding();

    // Run the Python script and capture its output
    let output = Command::new("python")
        .envs([
            ("X_API_KEY", env!("X_API_KEY")),
            ("CHAT_SYSTEM", include_str!("system_prompt")),
            ("CHAT_USER", &format!("ZIG->RUST\n\n{paths:?}")),
        ])
        .args(["build.py"])
        .output()
        .expect("Failed to execute Python script");

    if !output.status.success() {
        panic!(
            "Python script failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }

    // Get the script output (should be Rust FFI bindings content)
    let ffi_content = unsafe { String::from_utf8_unchecked(output.stdout.clone()) };

    let ffi_content = ffi_content.replace("\\n", "\n").replace("\\t", "\t");

    println!(
        "cargo:warning=Generated LLM completion {}",
        &String::from_utf8_lossy(&output.stderr)
    );

    // Parse the FFI content and extract file paths and their contents
    let parsed_files = parse_ffi_content(&ffi_content);

    fs::remove_dir_all("src/bindings");

    // Write each file to its respective path
    for (file_path, content) in parsed_files {
        // Create the full path relative to manifest_dir
        let full_path = manifest_dir.join(&file_path);

        // Create parent directories if they don't exist
        if let Some(parent) = full_path.parent() {
            fs::create_dir_all(parent)
                .expect(&format!("Failed to create directories for {}", file_path));
        }

        println!(
            "cargo:warning=Writing FFI bindings at {}",
            full_path.display()
        );
        // Write the content to the file
        let mut file =
            fs::File::create(&full_path).expect(&format!("Failed to create {}", file_path));
        file.write_all(content.as_bytes())
            .expect(&format!("Failed to write to {}", file_path));

        println!(
            "cargo:warning=Generated FFI bindings at {}",
            full_path.display()
        );
    }

    // Tell Cargo to re-run this if any of the input files change
    println!("cargo:rerun-if-changed=../../zig/base/include");
    println!("cargo:rerun-if-changed=../../zig/base/src/lib.zig");
    println!("cargo:rerun-if-changed=build.py");
    println!("cargo:rerun-if-changed=system_prompt");
}

/// Parse the FFI content and extract file paths and their contents
fn parse_ffi_content(content: &str) -> Vec<(String, String)> {
    let mut result = Vec::new();
    let mut current_path: Option<String> = None;
    let mut current_content = String::new();
    let mut in_code_block = false;

    // Define a regex pattern to match file paths in comments
    // e.g. "// /workspace/src/rust/base/bindings/c/ctx.rs"
    let path_pattern = Regex::new(r"^// (/?)src/.*\.rs$").unwrap();

    // Split the content by lines for processing
    let lines: Vec<&str> = content.lines().collect();

    for line in lines {
        println!("cargo:warning=1{}", &line);
        // Check if we're entering or leaving a code block
        if line.trim() == "```rust" {
            in_code_block = true;
            continue;
        } else if line.trim() == "```" {
            in_code_block = false;
            continue;
        }

        // Check if the line contains a file path
        if let Some(captures) = path_pattern.captures(line.trim()) {
            println!("cargo:warning=2{:?}", &captures);
            // If we have a current path already, save its content before moving on
            if let Some(path) = current_path.take() {
                println!("cargo:warning=3{}", &path);
                if !current_content.is_empty() {
                    result.push((path, current_content.trim().to_string()));
                    current_content.clear();
                }
            }

            // Extract the new path from the regex capture
            if let Some(path_match) = captures.get(0) {
                current_path = Some(
                    path_match
                        .as_str()
                        .trim_start_matches("//")
                        .trim()
                        .to_string(),
                );
            }
        } else if current_path.is_some() && in_code_block {
            // Only accumulate content if we're inside a code block and have a current path
            current_content.push_str(line);
            current_content.push('\n');
        }
    }

    // Add the last file if there's anything pending
    if let Some(path) = current_path {
        if !current_content.is_empty() {
            println!("cargo:warning=4{}", &path);
            result.push((path, current_content.trim().to_string()));
        }
    }

    result
}

fn collect_zig_headers_for_binding() -> String {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let include_dir = manifest_dir.join("../../zig/base/include");
    let src_dir = manifest_dir.join("../../zig/base/src");

    let mut header_info = String::new();

    // Add include directory structure
    header_info.push_str(&format!("INCLUDE_DIR: {}\n", include_dir.display()));

    // Collect all Zig header files from include directory
    if let Ok(entries) = std::fs::read_dir(&include_dir) {
        for entry in entries.filter_map(Result::ok) {
            if let Ok(file_type) = entry.file_type() {
                if file_type.is_file() && entry.path().extension().map_or(false, |ext| ext == "zig")
                {
                    // For each .zig file, read its contents
                    if let Ok(content) = std::fs::read_to_string(&entry.path()) {
                        let rel_path = entry.path().to_owned();
                        let rel_path2 = entry.path().to_owned();
                        let rel_path = rel_path.strip_prefix(&manifest_dir).unwrap_or(&rel_path2);
                        header_info.push_str(&format!("ZIG_HEADER: {}\n", rel_path.display()));
                        header_info
                            .push_str(&format!("BEGIN_CONTENT\n{}\nEND_CONTENT\n\n", content));
                    }
                }
            }
        }
    }

    // Add source lib.zig which contains the exports
    let lib_zig_path = src_dir.join("lib.zig");
    if let Ok(content) = std::fs::read_to_string(&lib_zig_path) {
        header_info.push_str(&format!("ZIG_SOURCE: lib.zig\n"));
        header_info.push_str(&format!("BEGIN_CONTENT\n{}\nEND_CONTENT\n\n", content));
    }

    // Map Zig types to Rust FFI types
    header_info.push_str("FFI_TYPE_MAPPING:\n");
    header_info.push_str("u8 -> u8\n");
    header_info.push_str("i32 -> i32\n");
    header_info.push_str("usize -> usize\n");
    header_info.push_str("*anyopaque -> *mut libc::c_void\n");
    header_info.push_str("?*anyopaque -> *mut libc::c_void\n");
    header_info.push_str("bool -> bool\n");
    header_info.push_str("extern struct -> #[repr(C)]\n");
    header_info.push_str("opaque -> struct\n");

    header_info
}

fn build_zig_library(manifest_dir: &PathBuf, target_dir: &PathBuf, profile: &str) {
    println!("cargo:warning=Building Zig library...");

    // Create output directory
    let lib_dir = target_dir.join(&profile);
    std::fs::create_dir_all(&lib_dir).expect("Failed to create library output directory");

    // Determine source and include directories
    let zig_root = manifest_dir.join("../../zig/base");
    let zig_src = zig_root.join("src/lib.zig");
    let zig_include = zig_root.join("include");

    // Library naming
    let lib_name = "deterministic-async-runtime";
    let lib_extension = if cfg!(target_os = "windows") {
        "dll"
    } else if cfg!(target_os = "macos") {
        "dylib"
    } else {
        "so"
    };

    // Zig adds '.o' to the output, so we need to account for that
    let output_file = format!("lib{}.{}.o", lib_name, lib_extension);
    let final_lib_file = format!("lib{}.{}", lib_name, lib_extension);
    let final_lib_path = lib_dir.join(&final_lib_file);

    // Optimization level
    let optimize = match profile {
        "debug" => "-ODebug",
        _ => "-OReleaseSafe",
    };

    // Build Zig library
    let output = Command::new("zig")
        .args([
            "build-lib",
            optimize,
            "--name",
            lib_name,
            "--library",
            "c",
            "-dynamic",
            "-I",
            zig_include.to_str().unwrap(),
            zig_src.to_str().unwrap(),
        ])
        .output();

    match output {
        Ok(output) => {
            // Print output for debugging
            println!(
                "cargo:warning=Zig build stdout: {}",
                String::from_utf8_lossy(&output.stdout)
            );
            println!(
                "cargo:warning=Zig build stderr: {}",
                String::from_utf8_lossy(&output.stderr)
            );

            // Check build status
            if !output.status.success() {
                panic!("Zig compilation failed: {}", output.status);
            }

            // Move the file to the target directory
            println!(
                "cargo:warning=Moving {} to {}",
                output_file,
                final_lib_path.display()
            );

            // First check if the file exists
            if !std::path::Path::new(&output_file).exists() {
                panic!("Zig output file not found: {}", output_file);
            }

            // Copy the file to the target directory
            std::fs::copy(&output_file, &final_lib_path).expect(&format!(
                "Failed to copy {} to {}",
                output_file,
                final_lib_path.display()
            ));

            // Remove the original file
            std::fs::remove_file(&output_file).expect(&format!("Failed to remove {}", output_file));
        }
        Err(e) => {
            panic!("Failed to execute Zig compiler: {}", e);
        }
    }

    // Tell cargo about the library
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=dylib=deterministic-async-runtime");

    // Rebuild if Zig sources change
    println!("cargo:rerun-if-changed=../../zig");
}
