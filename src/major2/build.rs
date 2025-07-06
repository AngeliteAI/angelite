use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    // Compile shaders first (for all platforms)
    compile_shaders();
    
    if cfg!(target_os = "macos") {
        // Run Swift compilation on macOS
        compile_swift_sources();
    } else if cfg!(target_os = "windows") {
        // Run Zig compilation to build a single binary for Windows
        compile_windows_binary();
    }
}

fn compile_shaders() {
    // Get output directory
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    
    // Define shader directories
    let gfx_shader_dir = manifest_dir.join("src/gfx/vk");
    let physx_shader_dir = manifest_dir.join("src/physx/vk");
    let worldgen_shader_dir = manifest_dir.join("src/universe/worldgen/vk");
    
    // Tell Cargo to rerun if any .glsl file changes
    for shader_dir in &[gfx_shader_dir, physx_shader_dir, worldgen_shader_dir] {
        if shader_dir.exists() {
            for entry in fs::read_dir(shader_dir).unwrap() {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    if path.extension().and_then(|s| s.to_str()) == Some("glsl") {
                        println!("cargo:rerun-if-changed={}", path.display());
                    }
                }
            }
        }
    }
    
    // Check if we have glslc in PATH first
    let glslc_path = if let Ok(path) = which::which("glslc") {
        eprintln!("Using system glslc at {:?}", path);
        path
    } else {
        // Build shaderc if not found in PATH
        let shaderc_dir = manifest_dir.join("../../vendor/shaderc");
        let shaderc_build_dir = out_dir.join("shaderc-build");
        
        // Find the glslc executable location
        let potential_glslc = if cfg!(target_os = "windows") {
            shaderc_build_dir.join("glslc/Release/glslc.exe")
        } else {
            shaderc_build_dir.join("glslc/glslc")
        };
        
        // Only build if glslc doesn't exist
        if !potential_glslc.exists() {
            eprintln!("Building shaderc in {:?}", shaderc_build_dir);
            
            // Create build directory for shaderc
            fs::create_dir_all(&shaderc_build_dir).unwrap();
            
            // Configure shaderc with CMake
            let cmake_config = Command::new("cmake")
                .current_dir(&shaderc_build_dir)
                .args(&[
                    &shaderc_dir.to_string_lossy(),
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DSHADERC_SKIP_TESTS=ON",
                    "-DSHADERC_SKIP_EXAMPLES=ON",
                    "-DSHADERC_SKIP_COPYRIGHT_CHECK=ON",
                ])
                .status()
                .expect("Failed to configure shaderc with CMake");
            
            if !cmake_config.success() {
                panic!("CMake configuration for shaderc failed");
            }
            
            // Build shaderc
            let cmake_build = Command::new("cmake")
                .current_dir(&shaderc_build_dir)
                .args(&["--build", ".", "--config", "Release"])
                .status()
                .expect("Failed to build shaderc");
            
            if !cmake_build.success() {
                panic!("Building shaderc failed");
            }
        }
        
        if !potential_glslc.exists() {
            panic!("glslc executable not found at {:?}", potential_glslc);
        }
        
        eprintln!("Using compiled glslc at {:?}", potential_glslc);
        potential_glslc
    };
    
    // Define shader directories
    let shader_dirs = vec![
        manifest_dir.join("src/gfx/vk"),
        manifest_dir.join("src/physx/vk"),
        manifest_dir.join("src/universe/worldgen/vk"),
    ];
    let output_shader_dir = out_dir.join("shaders");
    fs::create_dir_all(&output_shader_dir).unwrap();
    
    // Compile all shader files
    let shader_types = vec![
        ("vert", "vertex"),
        ("frag", "fragment"),
        ("geom", "geometry"),
        ("tesc", "tesscontrol"),
        ("tese", "tesseval"),
        ("comp", "compute"),
    ];
    
    for shader_dir in shader_dirs {
        if !shader_dir.exists() {
            continue;
        }
        
        for (extension, stage) in &shader_types {
        // Find all shader files with this extension
        let _pattern = format!("*.{}.glsl", extension);
        let shader_files = fs::read_dir(&shader_dir)
            .unwrap()
            .filter_map(|entry| {
                let entry = entry.ok()?;
                let path = entry.path();
                if path.is_file() && path.file_name()?.to_str()?.ends_with(&format!(".{}.glsl", extension)) {
                    Some(path)
                } else {
                    None
                }
            })
            .collect::<Vec<_>>();
        
        for shader_path in shader_files {
            let shader_name = shader_path.file_stem().unwrap().to_str().unwrap();
            let output_path = output_shader_dir.join(format!("{}.spirv", shader_name));
            let embed_path = shader_dir.join(format!("{}.spirv", shader_name));
            
            // Check if shader needs recompilation
            let needs_compile = if embed_path.exists() {
                let shader_modified = fs::metadata(&shader_path).unwrap().modified().unwrap();
                let spirv_modified = fs::metadata(&embed_path).unwrap().modified().unwrap();
                shader_modified > spirv_modified
            } else {
                true
            };
            
            if needs_compile {
                eprintln!("Compiling shader: {:?} -> {:?}", shader_path, output_path);
                
                let compile_status = Command::new(&glslc_path)
                    .args(&[
                        &format!("-fshader-stage={}", stage),
                        "--target-spv=spv1.3",
                        "-o", output_path.to_str().unwrap(),
                        shader_path.to_str().unwrap(),
                    ])
                    .status()
                    .expect("Failed to execute glslc");
                
                if !compile_status.success() {
                    panic!("Failed to compile shader: {:?}", shader_path);
                }
                
                // Copy the compiled SPIR-V to the source directory for embedding
                fs::copy(&output_path, &embed_path)
                    .expect("Failed to copy compiled shader");
                
                eprintln!("Compiled and copied shader to: {:?}", embed_path);
            } else {
                eprintln!("Shader {:?} is up to date", shader_name);
            }
        }
    }
    }
    
    eprintln!("Shader compilation complete");
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
    eprintln!("Swift compilation command: {:?}", command);

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

    eprintln!("Output directory: {}", out_dir.display());
    eprintln!("Temp directory: {}", temp_dir.display());

    // Get absolute path to the target directory
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let profile = env::var("PROFILE").unwrap();
    let target_dir = PathBuf::from(&manifest_dir)
        .join("..")
        .join("..")
        .join("target")
        .join(&profile);
    eprintln!("Target directory: {}", target_dir.display());

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

    eprintln!(
        "Copying build file: {} -> {}",
        build_zig_path.display(),
        temp_build_zig_path.display()
    );
    fs::copy(&build_zig_path, &temp_build_zig_path).expect("Failed to copy build.zig file");

    // Copy the build.zig.zon file to the temp directory
    let build_zig_zon_path = PathBuf::from("build.zig.zon");
    let temp_build_zig_zon_path = temp_dir.join("build.zig.zon");

    eprintln!(
        "Copying build.zig.zon file: {} -> {}",
        build_zig_zon_path.display(),
        temp_build_zig_zon_path.display()
    );
    fs::copy(&build_zig_zon_path, &temp_build_zig_zon_path)
        .expect("Failed to copy build.zig.zon file");

    // Create symlink to vendor directory instead of copying
    let vendor_path = PathBuf::from("../../vendor");
    let temp_vendor_path = temp_dir.join("vendor");

    // Create symlink to vendor directory
    if vendor_path.exists() {
        // Convert to absolute path to avoid path resolution issues
        let absolute_vendor_path = fs::canonicalize(&vendor_path)
            .expect("Failed to resolve absolute path to vendor directory");
        // Remove existing symlink/directory if it exists
        if temp_vendor_path.exists() {
            if temp_vendor_path.is_dir() {
                fs::remove_dir_all(&temp_vendor_path)
                    .expect("Failed to remove existing vendor directory");
            } else {
                fs::remove_file(&temp_vendor_path).expect("Failed to remove existing vendor file");
            }
        }

        #[cfg(windows)]
        {
            std::os::windows::fs::symlink_dir(&absolute_vendor_path, &temp_vendor_path)
                .expect("Failed to create symlink to vendor directory");
        }
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(&absolute_vendor_path, &temp_vendor_path)
                .expect("Failed to create symlink to vendor directory");
        }
        eprintln!(
            "Created symlink: {} -> {}",
            absolute_vendor_path.display(),
            temp_vendor_path.display()
        );
    } else {
        eprintln!(
            "Warning: vendor directory not found at {}",
            vendor_path.display()
        );
    }

    // Run zig build command
    eprintln!("Running zig build...");
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

    eprintln!(
        "Copying {} -> {}",
        source_dll.display(),
        output_dll.display()
    );
    fs::copy(&source_dll, &output_dll).expect("Failed to copy DLL file");

    eprintln!(
        "Copying {} -> {}",
        source_lib.display(),
        output_lib.display()
    );
    fs::copy(&source_lib, &output_lib).expect("Failed to copy LIB file");

    // Copy the DLL to the target directory where the executable can find it
    let target_dll = target_dir.join(format!("{}.dll", lib_name));
    eprintln!(
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
                    ext == "zig" || ext == "spirv"
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

                    eprintln!(
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
