use std::{path::Path, process::Command};

use image::Image;

pub trait Model {}

pub struct Params {}

pub struct Docker {}

mod image {
    use serde::Deserialize;

    use crate::Docker;

    pub struct Image {
        name: String,
        tag: String,
        manifests: Manifests,
        remotes: Remotes,
    }

    impl Image {
        fn new(name: impl AsRef<str>, tag: impl AsRef<str>) -> Image {
            Self {
                manifests: Manifests::pull(name, tag),
                remotes: Remotes::pull(name, tag),
                name: name.as_ref().to_string(),
                tag: tag.as_ref().to_string(),
            }
        }
    }

    #[derive(Deserialize)]
    pub struct Remotes {
        remotes: Vec<Remote>,
    }

    impl Remotes {
        fn pull(name: impl AsRef<str>, tag: impl AsRef<str>) -> Self {
            let data = Docker::command(["image", "inspect", &format!("{name}:{tag}")]);
            let Ok(manifests) = data else {
                panic!("whoopsie");
            };
            serde_json::from_str::<Self>(&manifests).unwrap()
        }
    }

    #[derive(Deserialize)]
    pub struct Remote {
        id: String,
    }

    #[derive(Deserialize)]
    pub struct Manifests {
        manifests: Vec<Manifest>,
    }

    impl Manifests {
        fn pull(name: impl AsRef<str>, tag: impl AsRef<str>) -> Self {
            let data = Docker::command(["maniest", "inspect", &format!("{name}:{tag}")]);
            let Ok(manifests) = data else {
                panic!("whoopsie");
            };
            serde_json::from_str::<Self>(&manifests).unwrap()
        }
    }

    #[derive(Deserialize)]
    pub struct Platform {
        architecture: String,
        os: String,
    }

    #[derive(Deserialize)]
    pub struct Manifest {
        size: String,
        digest: String,
        platform: Platform,
    }
}

pub struct Container {
    name: String,
    exists: bool,
    running: bool,
}

impl Docker {
    fn command<N: usize>(args: [impl AsRef<str>; N]) -> Result<String, String> {
        let output = Command::new("docker").args(args).output()?;

        if output.status.success() {
            // Successfully retrieved manifest
            let manifest = String::from_utf8(output.stdout)?;
        } else {
            // Command failed
            let error = String::from_utf8(output.stderr)?;
        }
    }

    fn image(name: impl AsRef<str>, tag: impl AsRef<str>) -> Image {
        Image {
            name: name.as_ref().to_string(),
            tag: tag.as_ref().to_string(),
            manifests: Manifests::pull(name, tag),
        }
    }

    fn container(name: impl AsRef<str>) {}
}

pub fn build<M: Model>(working_dir: impl AsRef<Path>) {}
