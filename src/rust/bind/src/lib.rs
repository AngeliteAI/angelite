use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    thread,
    time::{Duration, SystemTime},
};

use docker::{Docker, Image, container_config};

mod container;

pub enum Language {
    Rust,
    Zig,
}

pub struct Library {
    pub dir: PathBuf,
    pub lang: Language,
}

pub struct Config {
    pub workspace: PathBuf,
    pub source: Library,
    pub deps: Vec<Library>,
    pub target: Library,
}

use std::env;
use std::fs::{self, File};
use std::io::{self, Write};

/// Generate a Dockerfile from snippets in a directory and save it to a temporary location
///
/// # Arguments
/// * `snippets_dir` - Directory containing Dockerfile snippet files (named like 010_base_image, 020_basic_tools, etc.)
///
/// # Returns
/// * `Result<PathBuf, io::Error>` - Path to the generated Dockerfile or an error
pub fn generate_dockerfile_from_snippets(
    temp_name: impl AsRef<str>,
    snippets_dir: impl AsRef<Path>,
) -> Result<PathBuf, io::Error> {
    let snippets_path = snippets_dir.as_ref();

    // Check if the directory exists
    if !snippets_path.is_dir() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("Snippets directory not found: {:?}", snippets_path),
        ));
    }

    // Get all snippet files from the directory
    let mut snippet_files = Vec::new();
    for entry in fs::read_dir(snippets_path)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_file() && path.extension().is_none() {
            snippet_files.push(path);
        }
    }

    // Sort snippet files by filename (which should start with numbers)
    snippet_files.sort_by(|a, b| {
        let a_name = a.file_name().unwrap_or_default().to_string_lossy();
        let b_name = b.file_name().unwrap_or_default().to_string_lossy();
        a_name.cmp(&b_name)
    });

    // Create a temporary directory for the output
    let temp_dir = env::temp_dir().join(temp_name.as_ref());
    fs::create_dir_all(&temp_dir)?;

    // Path for the output Dockerfile
    let dockerfile_path = temp_dir.join("Dockerfile");

    // Create and open the output file
    let mut output_file = File::create(&dockerfile_path)?;

    // Write a header comment
    writeln!(output_file, "# Dockerfile generated from snippets")?;
    writeln!(output_file)?;

    // Process each snippet file
    for snippet_file in snippet_files {
        let snippet_name = snippet_file
            .file_name()
            .unwrap_or_default()
            .to_string_lossy();

        // Add a comment indicating which snippet this is
        writeln!(output_file, "# From snippet: {}", snippet_name)?;

        // Read and write the snippet content
        let content = fs::read_to_string(&snippet_file)?;
        writeln!(output_file, "{}", content)?;

        // Add a separator between snippets
        writeln!(output_file)?;
    }

    println!("Dockerfile generated at: {:?}", dockerfile_path);
    Ok(dockerfile_path)
}

pub fn bind(cfg: Config) {
    use std::time::{SystemTime, UNIX_EPOCH};

    // Generate a unique container name
    let id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos()
        .to_string();

    let container_name = format!("build_{}", id);

    let mut container = container_config();

    let dockersnippets = "./pipeline/zig_to_rust";
    // Generate Dockerfile from snippets
    let dockerfile_path = match generate_dockerfile_from_snippets(&container_name, dockersnippets) {
        Ok(path) => {
            // Log the Dockerfile content for debugging
            if let Ok(content) = fs::read_to_string(&path) {
                println!("Generated Dockerfile:\n{}", content);
            }
            path
        }
        Err(e) => {
            panic!("Failed to generate Dockerfile: {}", e);
        }
    };

    let dockerfile = fs::read_to_string(&dockerfile_path);

    let dockerfile_path = env::current_dir().unwrap().join("Dockerfile");

    fs::write(&dockerfile_path, dockerfile.unwrap());

    // Build a Docker image using the generated Dockerfile
    let image_tag = format!("zig_to_rust:{}", id);
    let build_result = Docker::build_image(
        dbg!(dockerfile_path.parent().unwrap()), // Context is the parent directory of the Dockerfile
        &image_tag,
        Some(&dockerfile_path),
        &[("deez", "nuts")],
    )
    .expect("failed to build image");

    // Check if image build was successful
    if !build_result.success {
        panic!("Failed to build Docker image: {}", build_result.stderr);
    }

    // Now use the built image instead of a pulled one
    let mut image = Image::new(
        image_tag.split(':').next().unwrap(),
        image_tag.split(':').nth(1).unwrap(),
    );

    let mut rev_lut = HashMap::new();

    let curr_env = env::current_dir().unwrap();
    let env_parent = cfg.workspace.as_os_str().to_str().unwrap();
    dbg!(&env_parent);

    let main = {
        let name = cfg.target.dir.file_name().and_then(|x| x.to_str()).unwrap();
        container = container.volume(env_parent, env_parent);
        let temp = cfg
            .target
            .dir
            .ancestors()
            .skip(1)
            .take(1)
            .collect::<PathBuf>();
        rev_lut.insert(
            env_parent.clone(),
            temp.as_os_str().to_str().unwrap().to_owned(),
        );
        name
    };

    container = container.cmd(vec!["sleep", "infinity"]);
    container = container.working_dir(env_parent.clone());

    let mut image = Image::new("rust", "latest");

    image.pull().expect("failed to pull image");

    let mut container = image
        .create_container(container_name, &container.build())
        .expect("failed to create container");

    container
        .refresh()
        .expect("failed to get container metadata");

    container.start().expect("failed to start container");

    container.copy_to(format!("{dockersnippets}/entry.sh"), "/entry.sh");
    container
        .exec(&["chmod +x /entry.sh"])
        .expect("failed to make target");

    let args = [
        ("WORKSPACE", &format!("{}/{}", env_parent, dockersnippets)),
        ("NAME", &"base".to_string()),
    ];

    let env = args
        .into_iter()
        .map(|(x, y)| format!("{x}={y}"))
        .collect::<Vec<_>>()
        .join(" ");

    container
        .exec(&[dbg!(format!("{env} /entry.sh"))])
        .expect("failed to make target");

    loop {
        let output = dbg!(
            container
                .exec(&["ls", "-a", "target/debug"])
                .expect("failed to get output")
        );
        let output = container
            .exec(&["RUSTFLAGS=\"-Awarnings\"", "cargo", "build"])
            .expect("failed to get output");

        println!("{}\n{}", &output.stdout, &output.stderr);

        if output
            .stderr
            .contains("failed to load source for dependency")
        {}

        if output
            .stderr
            .contains("failed to load source for dependency")
        {
            const FAILED_TO_READ: &str = "failed to read `";
            let dep_i = output.stderr.find(FAILED_TO_READ).unwrap() + FAILED_TO_READ.len();
            let (_, rest) = output.stderr.split_at(dep_i);
            let (dep, _) = rest.split_once("`").unwrap();
            let path = PathBuf::from(dep);
            let name = path.file_name().unwrap().to_str().unwrap();
            let target = dbg!(path.parent())
                .unwrap()
                .file_name()
                .unwrap()
                .to_str()
                .unwrap();
            let parent = path
                .ancestors()
                .take(path.ancestors().count() - 1)
                .collect::<PathBuf>();
            let parent_s = parent.to_str().unwrap_or_default();
            let win = format!("{parent_s}/{target}");
            dbg!(&win);
            let src = format!("{}/{target}", dbg!(&rev_lut)[dbg!(parent_s)]);
            container
                .exec(&["mkdir", "-p", &win])
                .expect("failed to make target");
            container
                .copy_to(dbg!(format!("{src}/{name}",)), &win)
                .expect("failed to load dependency");
            container
                .copy_to(dbg!(format!("{src}/src",)), &format!("{win}/src"))
                .expect("failed to load dependency");

            container
                .copy_to(dbg!(format!("{src}",)), &win)
                .expect("failed to load dependency");
        }
    }
}
