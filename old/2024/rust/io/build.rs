// angelite/src/rust/io/build.rs
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use bind::Output;
use bind::Rust;
use bind::Zig;

fn main() {
    // Tell Cargo when to rerun this build script
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../../zig/io/include");

    // Configure source and target directories
    let source_dir = Path::new("../../zig/io/include").canonicalize().unwrap();
    let out_dir = PathBuf::try_from("/Users/solmidnight/work/angelite/lib/rust").unwrap();
    let dest_path = Path::new(&out_dir).join("bindings.rs");

    // Import bind crate - assuming it's a path dependency in your Cargo.toml
    let bind = bind::Config {
        source: source_dir,
        target:  PathBuf::from(&out_dir),
        external_prompt: None,
    };

    let out = Output {
            lib_path: out_dir,
            crate_name: "io".to_string(),
        };

    // Call the bind functin and capture its return value
    // Disabled: use as needed due to experimentality
    //let bindings = bind::bind_and_verify::<Zig, Rust>(&bind, &out);
    

    // Tell Cargo where to find the bindings
    println!("cargo:rustc-env=BINDINGS_PATH={}", dest_path.display());
}
