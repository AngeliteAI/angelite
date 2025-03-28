use serde::{Deserialize, Serialize};
use std::{collections::HashMap, error::Error, fmt, path::Path, process::Command};

/// Error type for Docker operations
#[derive(Debug)]
pub struct DockerError {
    pub message: String,
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

/// Container configuration parameters for creating containers
#[derive(Debug, Clone, Default)]
pub struct ContainerConfig {
    pub env_vars: HashMap<String, String>,
    pub ports: Vec<(u16, u16)>,
    pub volumes: Vec<(String, String)>,
    pub cmd: Option<Vec<String>>,
    pub entrypoint: Option<Vec<String>>,
    pub network: Option<String>,
    pub labels: HashMap<String, String>,
    pub restart_policy: Option<String>,
    pub working_dir: Option<String>,
    pub platform: Option<String>, // New field for platform specification
}
/// Docker's container configuration structure used when parsing API responses
#[derive(Debug, Clone, Deserialize)]
pub struct DockerContainerConfig {
    #[serde(rename = "Hostname")]
    pub hostname: Option<String>,
    #[serde(rename = "Domainname")]
    pub domainname: Option<String>,
    #[serde(rename = "User")]
    pub user: Option<String>,
    #[serde(rename = "AttachStdin")]
    pub attach_stdin: Option<bool>,
    #[serde(rename = "AttachStdout")]
    pub attach_stdout: Option<bool>,
    #[serde(rename = "AttachStderr")]
    pub attach_stderr: Option<bool>,
    #[serde(rename = "Tty")]
    pub tty: Option<bool>,
    #[serde(rename = "OpenStdin")]
    pub open_stdin: Option<bool>,
    #[serde(rename = "StdinOnce")]
    pub stdin_once: Option<bool>,
    #[serde(rename = "Env")]
    pub env: Option<Vec<String>>,
    #[serde(rename = "Cmd")]
    pub cmd: Option<Vec<String>>,
    #[serde(rename = "Image")]
    pub image: Option<String>,
    #[serde(rename = "Volumes")]
    pub volumes: Option<serde_json::Value>, // Using Value to handle null or object
    #[serde(rename = "WorkingDir")]
    pub working_dir: Option<String>,
    #[serde(rename = "Entrypoint")]
    pub entrypoint: Option<Vec<String>>,
    #[serde(rename = "OnBuild")]
    pub on_build: Option<serde_json::Value>, // Using Value to handle null or array
    #[serde(rename = "Labels")]
    pub labels: Option<HashMap<String, String>>,
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
    pub config: Option<DockerContainerConfig>,
    #[serde(rename = "NetworkSettings")]
    pub network_settings: Option<NetworkSettings>,
    // Add fields that might be useful from Docker's output
    #[serde(rename = "HostConfig", default)]
    pub host_config: Option<HostConfig>,
    #[serde(rename = "Mounts", default)]
    pub mounts: Option<Vec<Mount>>,
    #[serde(rename = "Created", default)]
    pub created: Option<String>,
    #[serde(rename = "Path", default)]
    pub path: Option<String>,
    #[serde(rename = "Args", default)]
    pub args: Option<Vec<String>>,
    #[serde(rename = "ResolvConfPath", default)]
    pub resolv_conf_path: Option<String>,
    #[serde(rename = "HostnamePath", default)]
    pub hostname_path: Option<String>,
    #[serde(rename = "HostsPath", default)]
    pub hosts_path: Option<String>,
    #[serde(rename = "LogPath", default)]
    pub log_path: Option<String>,
    #[serde(rename = "RestartCount", default)]
    pub restart_count: Option<i32>,
    #[serde(rename = "Driver", default)]
    pub driver: Option<String>,
    #[serde(rename = "Platform", default)]
    pub platform: Option<String>,
    #[serde(rename = "MountLabel", default)]
    pub mount_label: Option<String>,
    #[serde(rename = "ProcessLabel", default)]
    pub process_label: Option<String>,
    #[serde(rename = "AppArmorProfile", default)]
    pub app_armor_profile: Option<String>,
    #[serde(rename = "ExecIDs", default)]
    pub exec_ids: Option<serde_json::Value>, // Can be null or array
    #[serde(rename = "GraphDriver", default)]
    pub graph_driver: Option<GraphDriver>,
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

// Additional structs needed for full Docker API coverage
#[derive(Debug, Clone, Deserialize, Default)]
pub struct HostConfig {
    #[serde(rename = "Binds", default)]
    pub binds: Option<Vec<String>>,
    #[serde(rename = "ContainerIDFile", default)]
    pub container_id_file: Option<String>,
    #[serde(rename = "LogConfig", default)]
    pub log_config: Option<LogConfig>,
    #[serde(rename = "NetworkMode", default)]
    pub network_mode: Option<String>,
    #[serde(rename = "PortBindings", default)]
    pub port_bindings: Option<HashMap<String, Vec<PortBinding>>>,
    #[serde(rename = "RestartPolicy", default)]
    pub restart_policy: Option<RestartPolicy>,
    #[serde(rename = "AutoRemove", default)]
    pub auto_remove: Option<bool>,
    #[serde(rename = "VolumeDriver", default)]
    pub volume_driver: Option<String>,
    #[serde(rename = "VolumesFrom", default)]
    pub volumes_from: Option<serde_json::Value>, // Can be null or array
    #[serde(rename = "ConsoleSize", default)]
    pub console_size: Option<Vec<u32>>,
    #[serde(rename = "Privileged", default)]
    pub privileged: Option<bool>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct LogConfig {
    #[serde(rename = "Type", default)]
    pub log_type: Option<String>,
    #[serde(rename = "Config", default)]
    pub config: Option<HashMap<String, String>>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct RestartPolicy {
    #[serde(rename = "Name", default)]
    pub name: Option<String>,
    #[serde(rename = "MaximumRetryCount", default)]
    pub maximum_retry_count: Option<i32>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct Mount {
    #[serde(rename = "Type", default)]
    pub mount_type: Option<String>,
    #[serde(rename = "Source", default)]
    pub source: Option<String>,
    #[serde(rename = "Destination", default)]
    pub destination: Option<String>,
    #[serde(rename = "Mode", default)]
    pub mode: Option<String>,
    #[serde(rename = "RW", default)]
    pub rw: Option<bool>,
    #[serde(rename = "Propagation", default)]
    pub propagation: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Default)]
pub struct GraphDriver {
    #[serde(rename = "Data", default)]
    pub data: Option<HashMap<String, String>>,
    #[serde(rename = "Name", default)]
    pub name: Option<String>,
}

/// Container represents a Docker container
pub struct Container {
    name: String,
    id: Option<String>,
    info: Option<ContainerInfo>,
}

impl Container {
    pub fn copy_dir_to_with_tar(
        &self,
        src_dir: impl AsRef<Path>,
        dest_dir: impl AsRef<str>,
    ) -> Result<(), DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        let src_path = src_dir.as_ref();
        if !src_path.is_dir() {
            return Err(DockerError {
                message: format!("Source path is not a directory: {:?}", src_path),
            });
        }

        // Create a tar archive in memory
        let mut tar_cmd = Command::new("tar");
        tar_cmd.current_dir(src_path.parent().unwrap_or(Path::new("/")));
        tar_cmd.args(["-cf", "-", src_path.file_name().unwrap().to_str().unwrap()]);

        let tar_process = tar_cmd.stdout(std::process::Stdio::piped()).spawn()?;

        // Pipe the tar output to docker exec command
        let docker_cmd = format!(
            "docker exec -i {} bash -c \"mkdir -p {} && tar -xf - -C {}\"",
            self.name,
            dest_dir.as_ref(),
            dest_dir.as_ref()
        );

        let mut docker_process = Command::new("bash")
            .arg("-c")
            .arg(docker_cmd)
            .stdin(std::process::Stdio::from(tar_process.stdout.unwrap()))
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()?;

        let output = docker_process.wait_with_output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(DockerError {
                message: format!("Failed to copy directory to container: {}", stderr),
            });
        }

        Ok(())
    }
    /// Copy a file from the host to the container
    pub fn copy_to(
        &self,
        src_path: impl AsRef<Path>,
        dest_path: impl AsRef<str>,
    ) -> Result<(), DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        let src_path_ref = src_path.as_ref();
        let src_path_str = src_path_ref.to_str().ok_or_else(|| DockerError {
            message: "Invalid source path".to_string(),
        })?;

        // Add a trailing slash to the source if it's a directory
        // This ensures Docker copies the contents, not the directory itself
        let src_for_cmd = if src_path_ref.is_dir() && !src_path_str.ends_with('/') {
            format!("{}/", src_path_str)
        } else {
            src_path_str.to_string()
        };

        let dest = format!("{}:{}", self.name, dest_path.as_ref());

        // Execute the docker cp command
        let result = Command::new("docker")
            .args(["cp", &src_for_cmd, &dest])
            .output()?;

        if !result.status.success() {
            let stderr = String::from_utf8_lossy(&result.stderr);
            return Err(DockerError {
                message: format!("Failed to copy files to container: {}", stderr),
            });
        }

        Ok(())
    }
    /// Copy a file from the container to the host
    pub fn copy_from(
        &self,
        src_path: impl AsRef<str>,
        dest_path: impl AsRef<Path>,
    ) -> Result<(), DockerError> {
        if !self.exists() {
            return Err(DockerError {
                message: format!("Container {} does not exist", self.name),
            });
        }

        // Format command using the cp subcommand
        let src = format!("{}:{}", self.name, src_path.as_ref());
        let dest_path_str = dest_path.as_ref().to_str().unwrap_or("");

        // Execute the cp command
        Docker::command(["cp", &src, dest_path_str])?;

        Ok(())
    }
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

    /// Get container environment variables
    pub fn env_vars(&self) -> Vec<String> {
        self.info
            .as_ref()
            .and_then(|info| info.config.as_ref())
            .and_then(|config| config.env.as_ref())
            .cloned()
            .unwrap_or_default()
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
            Err(e) => {
                self.id = None;
                self.info = None;
                Err(e)
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
        let output = (Command::new("docker").args(&args_ref).output()?);
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
            (Docker::command(["container", "inspect", "--format={{json .}}", name.as_ref()])?);
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

        if let Some(platform) = &config.platform {
            args_owned.push("--platform".to_string());
            args_owned.push(platform.clone());
        }

        // Add environment variables
        for (key, value) in &config.env_vars {
            args_owned.push("-e".to_string());
            let env_var = format!("{}={}", key, value);
            args_owned.push(env_var);
        }
        if let Some(dir) = &config.working_dir {
            args_owned.push("--workdir".to_string());
            args_owned.push(dir.clone());
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

        if config.labels.get("privileged") == Some(&"true".to_string()) {
            args_owned.push("--privileged".to_string());
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

        for arg in cmd {
            args_owned.push(arg.as_ref().to_string());
        }

        // Now create a vector of string slices
        let args_ref: Vec<&str> = args_owned.iter().map(|s| s.as_str()).collect();

        Docker::command_with_result(&["exec", name.as_ref(), "bash", "-c", &args_owned.join(" ")])
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
        build_args: &[(impl AsRef<str>, impl AsRef<str>)],
    ) -> Result<CommandResult, DockerError> {
        // Create vector of owned strings
        let mut args_owned = Vec::new();
        args_owned.push("build".to_string());

        for (k, v) in build_args {
            args_owned.push("--build-arg".to_string());
            let (k, v) = (k.as_ref(), v.as_ref());
            args_owned.push(format!("{k}={v}"));
        }

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
    pub fn platform(mut self, platform: impl Into<String>) -> Self {
        self.config.platform = Some(platform.into());
        self
    }
    pub fn privileged(mut self, enabled: bool) -> Self {
        if enabled {
            self.config
                .labels
                .insert("privileged".to_string(), "true".to_string());
        }
        self
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
    pub fn working_dir(mut self, dir: impl Into<String>) -> Self {
        self.config.working_dir = Some(dir.into());
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
