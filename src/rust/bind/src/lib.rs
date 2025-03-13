use std::{
    path::PathBuf,
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
    pub source: Library,
    pub deps: Vec<Library>,
    pub target: Library,
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

    // Create a container configuration
    let mut container = container_config();

    for Library { dir, .. } in &cfg.deps {
        let name = dir.file_name().and_then(|x| x.to_str()).unwrap();
        container = container.volume(dir.as_os_str().to_str().unwrap(), format!("/libs/{name}"));
    }

    {
        let name = cfg.source.dir.file_name().and_then(|x| x.to_str()).unwrap();
        container = container.volume(
            cfg.source.dir.as_os_str().to_str().unwrap(),
            format!("/src/{name}"),
        );
    }

    let mut image = Image::new("rust", "latest");

    image.pull().expect("failed to pull image");

    let mut container = image
        .create_container(container_name, &container.build())
        .expect("failed to create container");

    container
        .refresh()
        .expect("failed to get container metadata");

    container.start().expect("failed to start container");

    let output = container
        .exec(&["cd /src/ && cargo build"])
        .expect("failed to get output");
    dbg!(output.stdout);
}
