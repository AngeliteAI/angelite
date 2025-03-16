#![feature(unboxed_closures)]
use gemini::GeminiClient;
use std::{
    cell::{OnceCell, RefCell},
    collections::HashMap,
    env, fs,
    path::{Path, PathBuf},
    rc::Rc,
    sync::{Arc, OnceLock},
    time::{Duration, SystemTime},
};

use docker::{Container, Docker, Image, container_config};

mod container;

pub trait ContainerExt {
    fn inject(&self, script: impl AsRef<str>) -> Script;
}

impl ContainerExt for Container {
    fn inject(&self, script: impl AsRef<str>) -> Script {
        let script_content = script.as_ref();

        // Ask the container for a temporary file path
        let temp_path_output = self
            .exec(&["mktemp"])
            .expect("Failed to create temporary file in container");

        // Parse the output to get the path (mktemp outputs the created path)
        let temp_path_str = temp_path_output.stdout.trim();
        let mut script_path = PathBuf::from(temp_path_str);
        // Create a temporary file for the script
        script_path.push("script.sh"); // Or another appropriate name

        // Write the script content to the file
        std::fs::write(&script_path, script_content).expect("Failed to write script to container");

        Script {
            container: self,
            script_path,
        }
    }
}

pub enum Invalid {
    User,
    Agent,
}

pub enum Error {
    Missing { path: PathBuf },
    Invalid { src: Invalid, msg: String },
}

pub enum Language {
    Rust,
    Zig,
    Swift,
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

static CTX: OnceLock<Context> = OnceLock::new();

pub struct Gemini {
    client: GeminiClient,
    system: String,
}

impl Model for Gemini {
    fn new(system: String) -> Self {
        let client = GeminiClient::new("angelite", "us-central1", "gemini-2.0-flash")
            .with_temperature(0.2)
            .with_api_key(&*env::var("GEMINI_API_KEY").unwrap());

        Self { client, system }
    }

    fn respond(&self, prompt: String) -> String {
        self.client.generate_content(&prompt).unwrap()
    }
}

///Provides AI responses
pub trait Model {
    fn new(system: String) -> Self
    where
        Self: Sized;
    fn respond(&self, prompt: String) -> String;
}

///Interprets AI responses
pub struct Interpreter {
    model: Rc<dyn Model>,
}

pub struct Binder {
    model: Rc<dyn Model>,
}

///Represents a stage of work
pub trait Stage {
    fn priority(&self) -> u64 {
        500
    }
    fn installation<'a>(&self, container: &'a Container) -> Script<'a>;
}

pub trait Provider {
    fn setup(&self) -> Vec<Arc<dyn Stage>>;
}

pub trait Compiler: Provider {
    fn compile(&self, container: &Container);
}

pub struct Zig;
pub struct ZigInstall;

impl Stage for ZigInstall {
    fn installation<'a>(&self, container: &'a Container) -> Script<'a> {
        container.inject(include_str!("install_zig.sh").to_owned())
    }
}

impl Provider for Zig {
    fn setup(&self) -> Vec<Arc<dyn Stage>> {
        vec![Arc::new(ZigInstall)]
    }
}

pub struct Swift;
pub struct SwiftInstall;

impl Stage for SwiftInstall {
    fn installation<'a>(&self, container: &'a Container) -> Script<'a> {
        container.inject(include_str!("install_swift.sh").to_owned())
    }
}

impl Provider for Swift {
    fn setup(&self) -> Vec<Arc<dyn Stage>> {
        vec![Arc::new(SwiftInstall)]
    }
}

impl Compiler for Swift {
    fn compile(&self, container: &Container) {}
}

pub struct Context {
    temp: PathBuf,
}

pub struct Build {
    container: Container,
    source: Arc<dyn Provider>,
    target: Arc<dyn Compiler>,
}

impl Build {
    fn start(image: Image) {}
}

pub struct Script<'a> {
    container: &'a Container,
    script_path: PathBuf,
}

impl Script<'_> {
    fn run(&self) {
        let path = self.script_path.to_str().unwrap();
        self.container.exec(&["chmod", "+x", path]);
        self.container.exec(&[&*format!("/{}", path)]);
    }
}

impl Build {
    fn create(cfg: Config) -> Build {
        let container = {
            let container_config =
                container_config().working_dir(env::current_dir().unwrap().to_str().unwrap());
            let image = Image::new("alpine", "latest");
            let mut container = image
                .create_container("build", &container_config.build())
                .unwrap();
            container.refresh();
            container
        };

        let source = Arc::new(match cfg.source.lang {
            Language::Zig => Zig,
            _ => todo!(),
        }) as Arc<dyn Provider>;

        let target = Arc::new(match cfg.target.lang {
            Language::Swift => Swift,
            _ => todo!(),
        }) as Arc<dyn Compiler>;

        let mut stages = vec![];

        stages.extend(source.setup());
        stages.extend(target.setup());

        stages.sort_by_key(|x| x.priority());

        for stage in stages {
            stage.installation(&container).run();
        }

        Self {
            container,
            source,
            target,
        }
    }

    fn include(&self, host_path: impl AsRef<Path>) {
        let path_str = host_path.as_ref().to_str().unwrap();
        self.container
            .exec(&["mkdir", "-p", path_str])
            .expect("failed to create host directory in container");

        self.container
            .copy_to(path_str, path_str)
            .expect("failed to mount and copy host data");
    }

    fn compile(&self) {
        self.target.compile(&self.container);
    }
}

pub fn bind(cfg: Config) {}
