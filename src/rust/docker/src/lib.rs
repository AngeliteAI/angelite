use std::{error::Error, fmt, fs::File, io::Write, path::Path, process::Command};

use image::Image;

pub trait Model {
    fn get_image_name(&self) -> &str;
    fn get_params(&self) -> Params;
}

#[derive(Debug, Clone)]
pub struct Params {
    pub env_vars: Vec<(String, String)>,
    pub ports: Vec<(u16, u16)>,
    pub volumes: Vec<(String, String)>,
}

impl Default for Params {
    fn default() -> Self {
        Self {
            env_vars: Vec::new(),
            ports: Vec::new(),
            volumes: Vec::new(),
        }
    }
}

pub struct Docker {}

mod image {
    use serde::Deserialize;

    use crate::Docker;

    pub struct Image {
        pub name: String,
        pub tag: String,
        pub manifests: Manifests,
        pub remotes: Remotes,
    }

    impl Image {
        pub fn new(name: impl AsRef<str>, tag: impl AsRef<str>) -> Image {
            Self {
                manifests: Manifests::pull(name.as_ref(), tag.as_ref()),
                remotes: Remotes::pull(name.as_ref(), tag.as_ref()),
                name: name.as_ref().to_string(),
                tag: tag.as_ref().to_string(),
            }
        }

        pub fn full_name(&self) -> String {
            format!("{}:{}", self.name, self.tag)
        }
    }

    #[derive(Deserialize)]
    pub struct Remotes {
        remotes: Vec<Remote>,
    }

    impl Remotes {
        fn pull(name: impl AsRef<str>, tag: impl AsRef<str>) -> Self {
            let full_name = format!("{}:{}", name.as_ref(), tag.as_ref());
            let data = Docker::command(["image", "inspect", &full_name])
                .unwrap_or_else(|e| panic!("Failed to inspect image {}: {}", full_name, e));

            serde_json::from_str::<Self>(&data)
                .unwrap_or_else(|e| panic!("Failed to parse image data for {}: {}", full_name, e))
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
            let full_name = format!("{}:{}", name.as_ref(), tag.as_ref());
            // Fixed typo: "maniest" -> "manifest"
            let data = Docker::command(["manifest", "inspect", &full_name])
                .unwrap_or_else(|e| panic!("Failed to inspect manifest {}: {}", full_name, e));

            serde_json::from_str::<Self>(&data).unwrap_or_else(|e| {
                panic!("Failed to parse manifest data for {}: {}", full_name, e)
            })
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

#[derive(Debug)]
pub struct DockerError {
    message: String,
}

impl fmt::Display for DockerError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Docker error: {}", self.message)
    }
}

impl Error for DockerError {}

impl From<std::io::Error> for DockerError {
    fn from(err: std::io::Error) -> Self {
        DockerError {
            message: err.to_string(),
        }
    }
}

impl From<std::string::FromUtf8Error> for DockerError {
    fn from(err: std::string::FromUtf8Error) -> Self {
        DockerError {
            message: err.to_string(),
        }
    }
}

pub struct Container {
    name: String,
    exists: bool,
    running: bool,
}

impl Container {
    pub fn new(name: impl AsRef<str>) -> Self {
        let name_str = name.as_ref().to_string();
        let exists = Docker::container_exists(&name_str);
        let running = if exists {
            Docker::container_running(&name_str)
        } else {
            false
        };

        Self {
            name: name_str,
            exists,
            running,
        }
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn exists(&self) -> bool {
        self.exists
    }

    pub fn running(&self) -> bool {
        self.running
    }

    pub fn start(&self) -> Result<(), DockerError> {
        if !self.exists {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if self.running {
            return Ok(());
        }

        Docker::command(["container", "start", &self.name])?;
        Ok(())
    }

    pub fn stop(&self) -> Result<(), DockerError> {
        if !self.exists {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if !self.running {
            return Ok(());
        }

        Docker::command(["container", "stop", &self.name])?;
        Ok(())
    }

    pub fn remove(&self) -> Result<(), DockerError> {
        if !self.exists {
            return Ok(());
        }

        if self.running {
            self.stop()?;
        }

        Docker::command(["container", "rm", &self.name])?;
        Ok(())
    }

    pub fn exec<S: AsRef<str>>(&self, cmd: &[S]) -> Result<String, DockerError> {
        if !self.exists {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if !self.running {
            return Err(DockerError {
                message: format!("Container {} is not running", self.name),
            });
        }

        let mut args = vec!["exec", &self.name];
        for arg in cmd {
            args.push(arg.as_ref());
        }

        Docker::command(
            args.try_into()
                .unwrap_or_else(|_| panic!("Invalid command arguments")),
        )
    }
}

pub struct BuildOutput {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
    pub image_name: String,
}

// Include Dockerfile templates at compile time
mod templates {
    pub const RUST_BUILD: &str = include_str!("../templates/rust_build.dockerfile");
    pub const RUST_BUILD_CHECK: &str = include_str!("../templates/rust_build_check.dockerfile");
    pub const RUST_BUILD_RELEASE: &str = include_str!("../templates/rust_build_release.dockerfile");
}

impl Docker {
    pub fn command<S, const N: usize>(args: [S; N]) -> Result<String, DockerError>
    where
        S: AsRef<str>,
    {
        let args_ref: Vec<&str> = args.iter().map(|s| s.as_ref()).collect();
        let output = Command::new("docker").args(&args_ref).output()?;

        if output.status.success() {
            // Successfully executed command
            Ok(String::from_utf8(output.stdout)?)
        } else {
            // Command failed
            let error = String::from_utf8(output.stderr)?;
            Err(DockerError { message: error })
        }
    }

    pub fn command_with_output<S: AsRef<str>>(
        args: &[S],
    ) -> Result<(bool, String, String), DockerError> {
        let args_ref: Vec<&str> = args.iter().map(|s| s.as_ref()).collect();
        let output = Command::new("docker").args(&args_ref).output()?;

        let stdout = String::from_utf8(output.stdout)?;
        let stderr = String::from_utf8(output.stderr)?;

        Ok((output.status.success(), stdout, stderr))
    }

    pub fn image(name: impl AsRef<str>, tag: impl AsRef<str>) -> Image {
        Image::new(name, tag)
    }

    pub fn container(name: impl AsRef<str>) -> Container {
        Container::new(name)
    }

    pub fn container_exists(name: impl AsRef<str>) -> bool {
        let result = Command::new("docker")
            .args(["container", "inspect", name.as_ref()])
            .output();

        match result {
            Ok(output) => output.status.success(),
            Err(_) => false,
        }
    }

    pub fn container_running(name: impl AsRef<str>) -> bool {
        let result = Command::new("docker")
            .args([
                "container",
                "inspect",
                "--format={{.State.Running}}",
                name.as_ref(),
            ])
            .output();

        match result {
            Ok(output) if output.status.success() => {
                let status = String::from_utf8_lossy(&output.stdout).trim().to_string();
                status == "true"
            }
            _ => false,
        }
    }

    pub fn pull_image(name: impl AsRef<str>, tag: impl AsRef<str>) -> Result<Image, DockerError> {
        let full_name = format!("{}:{}", name.as_ref(), tag.as_ref());
        Docker::command(["pull", &full_name])?;
        Ok(Image::new(name, tag))
    }

    pub fn create_container(
        image: &Image,
        container_name: impl AsRef<str>,
        params: &Params,
    ) -> Result<Container, DockerError> {
        let mut args = vec!["container", "create", "--name", container_name.as_ref()];

        // Add environment variables
        for (key, value) in &params.env_vars {
            args.push("-e");
            args.push(&format!("{}={}", key, value));
        }

        // Add port mappings
        for (host, container) in &params.ports {
            args.push("-p");
            args.push(&format!("{}:{}", host, container));
        }

        // Add volume mappings
        for (host, container) in &params.volumes {
            args.push("-v");
            args.push(&format!("{}:{}", host, container));
        }

        // Add image name
        args.push(&image.full_name());

        Docker::command(
            args.try_into()
                .unwrap_or_else(|_| panic!("Invalid command arguments")),
        )?;

        Ok(Container::new(container_name))
    }

    pub fn build_rust_crate(
        rust_project_path: impl AsRef<Path>,
        image_name: impl AsRef<str>,
        log_file: Option<impl AsRef<Path>>,
        release: bool,
    ) -> Result<BuildOutput, DockerError> {
        let project_path = rust_project_path.as_ref().to_string_lossy().to_string();
        let img_name = image_name.as_ref().to_string();

        // Choose the appropriate Dockerfile template
        let dockerfile_content = if release {
            templates::RUST_BUILD_RELEASE
        } else {
            templates::RUST_BUILD
        };

        // Write Dockerfile to the project directory
        let dockerfile_path = Path::new(&project_path).join("Dockerfile");
        let mut file = File::create(&dockerfile_path)?;
        file.write_all(dockerfile_content.as_bytes())?;

        // Build the Docker image
        let args = &["build", "-t", &img_name, &project_path];
        let (success, stdout, stderr) = Docker::command_with_output(args)?;

        // Save logs if requested
        if let Some(log_path) = log_file {
            let mut log_file = File::create(log_path.as_ref())?;
            log_file.write_all(b"--- STDOUT ---\n")?;
            log_file.write_all(stdout.as_bytes())?;
            log_file.write_all(b"\n--- STDERR ---\n")?;
            log_file.write_all(stderr.as_bytes())?;
        }

        Ok(BuildOutput {
            success,
            stdout,
            stderr,
            image_name: img_name,
        })
    }

    pub fn check_rust_build(
        rust_project_path: impl AsRef<Path>,
        image_name: impl AsRef<str>,
        log_file: Option<impl AsRef<Path>>,
    ) -> Result<BuildOutput, DockerError> {
        let project_path = rust_project_path.as_ref().to_string_lossy().to_string();
        let img_name = image_name.as_ref().to_string();

        // Use the check-only Dockerfile
        let dockerfile_content = templates::RUST_BUILD_CHECK;

        // Write Dockerfile to the project directory
        let dockerfile_path = Path::new(&project_path).join("Dockerfile");
        let mut file = File::create(&dockerfile_path)?;
        file.write_all(dockerfile_content.as_bytes())?;

        // Build the Docker image
        let args = &["build", "-t", &img_name, &project_path];
        let (success, stdout, stderr) = Docker::command_with_output(args)?;

        // Save logs if requested
        if let Some(log_path) = log_file {
            let mut log_file = File::create(log_path.as_ref())?;
            log_file.write_all(b"--- STDOUT ---\n")?;
            log_file.write_all(stdout.as_bytes())?;
            log_file.write_all(b"\n--- STDERR ---\n")?;
            log_file.write_all(stderr.as_bytes())?;
        }

        Ok(BuildOutput {
            success,
            stdout,
            stderr,
            image_name: img_name,
        })
    }

    pub fn inspect_rust_build(build_output: &BuildOutput) -> Result<bool, DockerError> {
        if !build_output.success {
            return Ok(false);
        }

        // Create a temporary container to inspect the build
        let container_name = format!(
            "inspect_{}",
            build_output.image_name.replace(':', '_').replace('/', '_')
        );

        // First remove any existing container with this name
        let _ = Command::new("docker")
            .args(["rm", "-f", &container_name])
            .output();

        // Create and run the container
        let args = &[
            "run",
            "--name",
            &container_name,
            "-d",
            &build_output.image_name,
        ];

        let (success, _, _) = Docker::command_with_output(args)?;
        if !success {
            return Ok(false);
        }

        // Clean up the container
        let _ = Command::new("docker")
            .args(["rm", "-f", &container_name])
            .output();

        Ok(true)
    }
}

pub fn build<M: Model>(working_dir: impl AsRef<Path>, model: &M) -> Result<Container, DockerError> {
    let working_dir = working_dir.as_ref();

    // Check if working directory exists
    if !working_dir.exists() || !working_dir.is_dir() {
        return Err(DockerError {
            message: format!(
                "Working directory does not exist: {}",
                working_dir.display()
            ),
        });
    }

    let image_name = model.get_image_name();
    let (name, tag) = if let Some(idx) = image_name.find(':') {
        (&image_name[..idx], &image_name[idx + 1..])
    } else {
        (image_name, "latest")
    };

    // Pull the image first
    let image = Docker::pull_image(name, tag)?;

    // Generate a container name based on the model name
    let container_name = format!("model_{}", name.replace('/', "_"));

    // Create the container with model parameters
    let params = model.get_params();
    Docker::create_container(&image, &container_name, &params)
}

// For Rust crate building
pub fn build_rust_project(
    project_path: impl AsRef<Path>,
    image_name: impl AsRef<str>,
    release: bool,
) -> Result<BuildOutput, DockerError> {
    Docker::build_rust_crate(project_path, image_name, None, release)
}

pub fn check_rust_project(
    project_path: impl AsRef<Path>,
    image_name: impl AsRef<str>,
    log_file: impl AsRef<Path>,
) -> Result<bool, DockerError> {
    let build_output = Docker::check_rust_build(project_path, image_name, Some(log_file))?;
    Ok(build_output.success)
}

pub fn build_and_inspect_rust_project(
    project_path: impl AsRef<Path>,
    image_name: impl AsRef<str>,
    log_file: impl AsRef<Path>,
    release: bool,
) -> Result<bool, DockerError> {
    let build_output = Docker::build_rust_crate(project_path, image_name, Some(log_file), release)?;

    if !build_output.success {
        return Ok(false);
    }

    Docker::inspect_rust_build(&build_output)
}
