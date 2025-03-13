use serde::{Deserialize, Serialize};
use std::{collections::HashMap, error::Error, fmt, path::Path, process::Command};

/// Error type for Docker operations
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

impl From<serde_json::Error> for DockerError {
    fn from(err: serde_json::Error) -> Self {
        DockerError {
            message: format!("JSON error: {}", err),
        }
    }
}

/// Container configuration parameters
#[derive(Debug, Clone, Default, Deserialize)]
pub struct ContainerConfig {
    pub env_vars: HashMap<String, String>,
    pub ports: Vec<(u16, u16)>,
    pub volumes: Vec<(String, String)>,
    pub cmd: Option<Vec<String>>,
    pub entrypoint: Option<Vec<String>>,
    pub network: Option<String>,
    pub labels: HashMap<String, String>,
    pub restart_policy: Option<String>,
}

/// Command execution result
#[derive(Debug, Clone)]
pub struct CommandResult {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
    pub exit_code: i32,
}

/// Docker image information
#[derive(Debug, Clone, Deserialize)]
pub struct ImageInfo {
    #[serde(rename = "Id")]
    pub id: String,
    #[serde(rename = "Created")]
    pub created: String,
    #[serde(rename = "Size")]
    pub size: u64,
    #[serde(rename = "RepoTags")]
    pub repo_tags: Vec<String>,
    #[serde(rename = "Architecture")]
    pub architecture: Option<String>,
    #[serde(rename = "Os")]
    pub os: Option<String>,
}

/// Container information
#[derive(Debug, Clone, Deserialize)]
pub struct ContainerInfo {
    #[serde(rename = "Id")]
    pub id: String,
    #[serde(rename = "Name")]
    pub name: String,
    #[serde(rename = "Image")]
    pub image: String,
    #[serde(rename = "State")]
    pub state: ContainerState,
    #[serde(rename = "Config")]
    pub config: Option<ContainerConfig>,
    #[serde(rename = "NetworkSettings")]
    pub network_settings: Option<NetworkSettings>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ContainerState {
    #[serde(rename = "Status")]
    pub status: String,
    #[serde(rename = "Running")]
    pub running: bool,
    #[serde(rename = "Paused")]
    pub paused: bool,
    #[serde(rename = "Restarting")]
    pub restarting: bool,
    #[serde(rename = "ExitCode")]
    pub exit_code: i32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NetworkSettings {
    #[serde(rename = "IPAddress")]
    pub ip_address: String,
    #[serde(rename = "Ports")]
    pub ports: Option<HashMap<String, Vec<PortBinding>>>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PortBinding {
    #[serde(rename = "HostIp")]
    pub host_ip: String,
    #[serde(rename = "HostPort")]
    pub host_port: String,
}

/// Container represents a Docker container
pub struct Container {
    name: String,
    id: Option<String>,
    info: Option<ContainerInfo>,
}

impl Container {
    /// Create a new Container instance
    pub fn new(name: impl AsRef<str>) -> Self {
        let name_str = name.as_ref().to_string();
        let mut container = Self {
            name: name_str,
            id: None,
            info: None,
        };

        // Try to get container info
        let _ = container.refresh();

        container
    }

    /// Get container name
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Get container ID if available
    pub fn id(&self) -> Option<&str> {
        self.id.as_deref()
    }

    /// Check if container exists
    pub fn exists(&self) -> bool {
        self.id.is_some()
    }

    /// Check if container is running
    pub fn running(&self) -> bool {
        if let Some(info) = &self.info {
            info.state.running
        } else {
            false
        }
    }

    /// Get container status
    pub fn status(&self) -> Option<&str> {
        self.info.as_ref().map(|info| info.state.status.as_str())
    }

    /// Get container IP address
    pub fn ip_address(&self) -> Option<&str> {
        self.info
            .as_ref()
            .and_then(|info| info.network_settings.as_ref())
            .map(|network| network.ip_address.as_str())
    }

    /// Refresh container information
    pub fn refresh(&mut self) -> Result<(), DockerError> {
        match Docker::inspect_container(&self.name) {
            Ok(info) => {
                self.id = Some(info.id.clone());
                self.info = Some(info);
                Ok(())
            }
            Err(e) => {
                self.id = None;
                self.info = None;
                Err(e)
            }
        }
    }

    /// Start the container
    pub fn start(&mut self) -> Result<(), DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if self.running() {
            return Ok(());
        }

        Docker::start_container(&self.name)?;
        self.refresh()?;
        Ok(())
    }

    /// Stop the container
    pub fn stop(&mut self) -> Result<(), DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if !self.running() {
            return Ok(());
        }

        Docker::stop_container(&self.name)?;
        self.refresh()?;
        Ok(())
    }

    /// Remove the container
    pub fn remove(&mut self) -> Result<(), DockerError> {
        if !self.exists() {
            return Ok(());
        }

        if self.running() {
            self.stop()?;
        }

        Docker::remove_container(&self.name)?;
        self.id = None;
        self.info = None;
        Ok(())
    }

    /// Execute a command in the container
    pub fn exec<S: AsRef<str>>(&self, cmd: &[S]) -> Result<CommandResult, DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        if !self.running() {
            return Err(DockerError {
                message: format!("Container {} is not running", self.name),
            });
        }

        Docker::exec_container(&self.name, cmd)
    }

    /// Get container logs
    pub fn logs(&self, tail: Option<usize>) -> Result<String, DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        Docker::container_logs(&self.name, tail)
    }
}

/// Docker image representation
pub struct Image {
    name: String,
    tag: String,
    id: Option<String>,
    info: Option<ImageInfo>,
}

impl Image {
    /// Create a new Image instance
    pub fn new(name: impl AsRef<str>, tag: impl AsRef<str>) -> Self {
        let name_str = name.as_ref().to_string();
        let tag_str = tag.as_ref().to_string();
        let mut image = Self {
            name: name_str,
            tag: tag_str,
            id: None,
            info: None,
        };

        // Try to get image info
        let _ = image.refresh();

        image
    }

    /// Get image name
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Get image tag
    pub fn tag(&self) -> &str {
        &self.tag
    }

    /// Get full image name (name:tag)
    pub fn full_name(&self) -> String {
        format!("{}:{}", self.name, self.tag)
    }

    /// Get image ID if available
    pub fn id(&self) -> Option<&str> {
        self.id.as_deref()
    }

    /// Check if image exists locally
    pub fn exists(&self) -> bool {
        self.id.is_some()
    }

    /// Refresh image information
    pub fn refresh(&mut self) -> Result<(), DockerError> {
        match Docker::inspect_image(self.full_name()) {
            Ok(info) => {
                self.id = Some(info.id.clone());
                self.info = Some(info);
                Ok(())
            }
            Err(_) => {
                self.id = None;
                self.info = None;
                Ok(())
            }
        }
    }

    /// Pull the image from registry
    pub fn pull(&mut self) -> Result<(), DockerError> {
        Docker::pull_image(&self.name, &self.tag)?;
        self.refresh()?;
        Ok(())
    }

    /// Remove the image
    pub fn remove(&mut self) -> Result<(), DockerError> {
        if !self.exists() {
            return Ok(());
        }

        Docker::remove_image(&self.full_name())?;
        self.id = None;
        self.info = None;
        Ok(())
    }

    /// Create a container from this image
    pub fn create_container(
        &self,
        container_name: impl AsRef<str>,
        config: &ContainerConfig,
    ) -> Result<Container, DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Image {} does not exist", self.full_name()),
            });
        }

        Docker::create_container(&self.full_name(), container_name, config)
    }
}

/// Main Docker API
pub struct Docker;

impl Docker {
    /// Execute a Docker command with fixed number of arguments
    pub fn command<S, const N: usize>(args: [S; N]) -> Result<String, DockerError>
    where
        S: AsRef<str>,
    {
        let args_ref: Vec<&str> = args.iter().map(|s| s.as_ref()).collect();
        let output = dbg!(Command::new("docker").args(&args_ref).output()?);
        if output.status.success() {
            Ok(String::from_utf8(output.stdout)?)
        } else {
            let error = String::from_utf8(output.stderr)?;
            Err(DockerError { message: error })
        }
    }

    /// Execute a Docker command with variable arguments
    pub fn command_with_args<S: AsRef<str>>(args: &[S]) -> Result<String, DockerError> {
        let args_ref: Vec<&str> = args.iter().map(|s| s.as_ref()).collect();
        let output = Command::new("docker").args(&args_ref).output()?;

        if output.status.success() {
            Ok(String::from_utf8(output.stdout)?)
        } else {
            let error = String::from_utf8(output.stderr)?;
            Err(DockerError { message: error })
        }
    }

    /// Execute a Docker command and get detailed result
    pub fn command_with_result<S: AsRef<str>>(args: &[S]) -> Result<CommandResult, DockerError> {
        let args_ref: Vec<&str> = args.iter().map(|s| s.as_ref()).collect();
        let output = Command::new("docker").args(&args_ref).output()?;

        let stdout = String::from_utf8(output.stdout)?;
        let stderr = String::from_utf8(output.stderr)?;
        let exit_code = output.status.code().unwrap_or(-1);

        Ok(CommandResult {
            success: output.status.success(),
            stdout,
            stderr,
            exit_code,
        })
    }

    /// Create a new Image object
    pub fn image(name: impl AsRef<str>, tag: impl AsRef<str>) -> Image {
        Image::new(name, tag)
    }

    /// Create a new Container object
    pub fn container(name: impl AsRef<str>) -> Container {
        Container::new(name)
    }

    /// Check if a container exists
    pub fn container_exists(name: impl AsRef<str>) -> bool {
        let result = Command::new("docker")
            .args(["container", "inspect", name.as_ref()])
            .output();

        match result {
            Ok(output) => output.status.success(),
            Err(_) => false,
        }
    }

    /// Check if a container is running
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

    /// Get detailed information about a container
    pub fn inspect_container(name: impl AsRef<str>) -> Result<ContainerInfo, DockerError> {
        let output =
            Docker::command(["container", "inspect", "--format={{json .}}", name.as_ref()])?;
        Ok(serde_json::from_str(&output)?)
    }

    /// Get detailed information about an image
    pub fn inspect_image(name: impl AsRef<str>) -> Result<ImageInfo, DockerError> {
        let output = Docker::command(["image", "inspect", "--format={{json .}}", name.as_ref()])?;
        Ok(serde_json::from_str(&output)?)
    }

    /// Pull an image from registry
    pub fn pull_image(name: impl AsRef<str>, tag: impl AsRef<str>) -> Result<(), DockerError> {
        let full_name = format!("{}:{}", name.as_ref(), tag.as_ref());
        let args = ["pull", full_name.as_str()];
        Docker::command(args)?;
        Ok(())
    }

    /// Remove an image
    pub fn remove_image(name: impl AsRef<str>) -> Result<(), DockerError> {
        Docker::command(["rmi", name.as_ref()])?;
        Ok(())
    }

    /// Create a container from an image
    pub fn create_container(
        image: impl AsRef<str>,
        container_name: impl AsRef<str>,
        config: &ContainerConfig,
    ) -> Result<Container, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("container".to_string());
        args_owned.push("create".to_string());
        args_owned.push("--name".to_string());
        args_owned.push(container_name.as_ref().to_string());

        // Add environment variables
        for (key, value) in &config.env_vars {
            args_owned.push("-e".to_string());
            let env_var = format!("{}={}", key, value);
            args_owned.push(env_var);
        }

        // Add port mappings
        for (host, container) in &config.ports {
            args_owned.push("-p".to_string());
            let port_mapping = format!("{}:{}", host, container);
            args_owned.push(port_mapping);
        }

        // Add volume mappings
        for (host, container) in &config.volumes {
            args_owned.push("-v".to_string());
            let volume_mapping = format!("{}:{}", host, container);
            args_owned.push(volume_mapping);
        }

        // Add network if specified
        if let Some(network) = &config.network {
            args_owned.push("--network".to_string());
            args_owned.push(network.clone());
        }

        // Add restart policy if specified
        if let Some(policy) = &config.restart_policy {
            args_owned.push("--restart".to_string());
            args_owned.push(policy.clone());
        }

        // Add labels
        for (key, value) in &config.labels {
            args_owned.push("--label".to_string());
            let label = format!("{}={}", key, value);
            args_owned.push(label);
        }

        // Add custom entrypoint if specified
        if let Some(entrypoint) = &config.entrypoint {
            args_owned.push("--entrypoint".to_string());
            args_owned.push(entrypoint.join(" "));
        }

        // Add image name
        args_owned.push(image.as_ref().to_string());

        // Add command if specified
        if let Some(cmd) = &config.cmd {
            for arg in cmd {
                args_owned.push(arg.clone());
            }
        }

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        // Call the function with slices
        Docker::command_with_args(&args_ref)?;

        Ok(Container::new(container_name))
    }

    /// Start a container
    pub fn start_container(name: impl AsRef<str>) -> Result<(), DockerError> {
        Docker::command(["container", "start", name.as_ref()])?;
        Ok(())
    }

    /// Stop a container
    pub fn stop_container(name: impl AsRef<str>) -> Result<(), DockerError> {
        Docker::command(["container", "stop", name.as_ref()])?;
        Ok(())
    }

    /// Remove a container
    pub fn remove_container(name: impl AsRef<str>) -> Result<(), DockerError> {
        Docker::command(["container", "rm", name.as_ref()])?;
        Ok(())
    }

    /// Execute a command in a running container
    pub fn exec_container<S: AsRef<str>>(
        name: impl AsRef<str>,
        cmd: &[S],
    ) -> Result<CommandResult, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("exec".to_string());
        args_owned.push(name.as_ref().to_string());

        for arg in cmd {
            args_owned.push(arg.as_ref().to_string());
        }

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        Docker::command_with_result(&args_ref)
    }

    /// Get container logs
    pub fn container_logs(
        name: impl AsRef<str>,
        tail: Option<usize>,
    ) -> Result<String, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("logs".to_string());

        if let Some(n) = tail {
            args_owned.push("--tail".to_string());
            args_owned.push(n.to_string());
        }

        args_owned.push(name.as_ref().to_string());

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        Docker::command_with_args(&args_ref)
    }

    /// List all containers
    pub fn list_containers(all: bool) -> Result<Vec<Container>, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("container".to_string());
        args_owned.push("ls".to_string());
        args_owned.push("--format={{.Names}}".to_string());

        if all {
            args_owned.push("-a".to_string());
        }

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        let output = Docker::command_with_args(&args_ref)?;
        let names = output
            .lines()
            .map(|line| line.trim())
            .filter(|line| !line.is_empty())
            .map(|name| Container::new(name))
            .collect();

        Ok(names)
    }

    /// List all images
    pub fn list_images() -> Result<Vec<Image>, DockerError> {
        let args_owned = vec![
            "image".to_string(),
            "ls".to_string(),
            "--format={{.Repository}}:{{.Tag}}".to_string(),
        ];

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        let output = Docker::command_with_args(&args_ref)?;
        let image_tags = output
            .lines()
            .map(|line| line.trim())
            .filter(|line| !line.is_empty() && !line.contains("<none>"))
            .collect::<Vec<_>>();

        let mut images = Vec::new();
        for image_tag in image_tags {
            if let Some(idx) = image_tag.rfind(':') {
                let name = &image_tag[..idx];
                let tag = &image_tag[idx + 1..];
                images.push(Image::new(name, tag));
            }
        }

        Ok(images)
    }

    /// Build an image from a Dockerfile
    pub fn build_image(
        context_path: impl AsRef<Path>,
        tag: impl AsRef<str>,
        dockerfile: Option<impl AsRef<Path>>,
    ) -> Result<CommandResult, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("build".to_string());
        args_owned.push("-t".to_string());
        args_owned.push(tag.as_ref().to_string());

        if let Some(path) = dockerfile {
            args_owned.push("-f".to_string());
            let path_str = path.as_ref().to_str().unwrap_or("Dockerfile").to_string();
            args_owned.push(path_str);
        }

        let context_str = context_path.as_ref().to_str().unwrap_or(".").to_string();
        args_owned.push(context_str);

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        Docker::command_with_result(&args_ref)
    }

    /// Check Docker daemon status
    pub fn is_available() -> bool {
        let result = Command::new("docker").args(["info"]).output();

        match result {
            Ok(output) => output.status.success(),
            Err(_) => false,
        }
    }

    /// Get Docker version information
    pub fn version() -> Result<String, DockerError> {
        Docker::command(["version", "--format={{json .}}"])
    }
}

/// Create a default container config
pub fn default_container_config() -> ContainerConfig {
    ContainerConfig::default()
}

/// Build a container config with common options
pub fn container_config() -> ContainerConfigBuilder {
    ContainerConfigBuilder::new()
}

/// Builder for ContainerConfig
pub struct ContainerConfigBuilder {
    config: ContainerConfig,
}

impl ContainerConfigBuilder {
    /// Create a new ContainerConfigBuilder
    pub fn new() -> Self {
        Self {
            config: ContainerConfig::default(),
        }
    }

    /// Add an environment variable
    pub fn env(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.config.env_vars.insert(key.into(), value.into());
        self
    }

    /// Add a port mapping
    pub fn port(mut self, host: u16, container: u16) -> Self {
        self.config.ports.push((host, container));
        self
    }

    /// Add a volume mapping
    pub fn volume(mut self, host: impl Into<String>, container: impl Into<String>) -> Self {
        self.config.volumes.push((host.into(), container.into()));
        self
    }

    /// Set command to run
    pub fn cmd(mut self, args: Vec<impl Into<String>>) -> Self {
        self.config.cmd = Some(args.into_iter().map(|s| s.into()).collect());
        self
    }

    /// Set entrypoint
    pub fn entrypoint(mut self, args: Vec<impl Into<String>>) -> Self {
        self.config.entrypoint = Some(args.into_iter().map(|s| s.into()).collect());
        self
    }

    /// Set network
    pub fn network(mut self, network: impl Into<String>) -> Self {
        self.config.network = Some(network.into());
        self
    }

    /// Add a label
    pub fn label(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.config.labels.insert(key.into(), value.into());
        self
    }

    /// Set restart policy
    pub fn restart(mut self, policy: impl Into<String>) -> Self {
        self.config.restart_policy = Some(policy.into());
        self
    }

    /// Build the ContainerConfig
    pub fn build(self) -> ContainerConfig {
        self.config
    }
}
