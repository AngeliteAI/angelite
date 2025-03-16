#![feature(unboxed_closures)]
use std::{
    cell::{OnceCell, RefCell},
    collections::HashMap,
    env, fs,
    path::{Path, PathBuf},
    rc::Rc,
    sync::Arc,
    time::{Duration, SystemTime},
};
use thread::Local;

use docker::{Container, Docker, Image, container_config};

mod container;

pub trait ContainerExt {
    fn inject(script: impl AsRef<str>) -> Script;
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

static CTX: Local<OnceCell<Context>> = OnceCell::new();

///Provides AI responses
pub trait Model {
    fn new(system: String) -> Self;
    fn respond(&self, prompt: String) -> Self;
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
    fn priority(&self) -> u64;
    fn installation(&self, container: &Container) -> Script;
}

pub trait Provider {
    fn setup(&self) -> Vec<Stage>;
}

pub trait Compiler: Provider {
    fn compile(&self, container: &Container);
}

pub struct Zig;

impl Provider for Zig {
    fn setup(&self) -> Vec<Stage> {}
}

pub struct Swift {}

impl Provider for Swift {
    fn setup(&self) -> Vec<Stage> {}
}

impl Compiler for Swift {
    fn compile(&self) {}
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
    container_path: PathBuf,
}

impl Script<'a> {
    fn run(&self) {
        let path = self.container_path.to_str().unwrap();
        self.container.exec(&["chmod", "+x", path]);
        self.container.exec(&[&*format!("/{}", path)])
    }
}

impl Build {
    fn create(cfg: Config) -> Build {
        let container = {
            let container_config = container_config();
            container_config.working_dir(env::current_dir().unwrap());
            let image = Image::new("alpine", "latest");
            let container = image.create_container("build", container_config).unwrap();
            container.refresh();
            container
        };

        let source = Arc::new(match cfg.source {
            Language::Zig => Zig,
            _ => todo!(),
        }) as Arc<dyn Provider>;

        let target = Arc::new(match cfg.target {
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

pub fn bind(cfg: Config) {
    let lib_name = "math";
    use std::time::{SystemTime, UNIX_EPOCH};

    // Generate a unique container name
    let id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos()
        .to_string();

    let container_name = format!("build_{}", id);

    let mut container = container_config();

    let dockersnippets = "/Users/solmidnight/work/angelite/pipeline/zig_to_rust";
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

    container
        .copy_to(format!("{dockersnippets}/entry.sh"), "/entry.sh")
        .unwrap();
    container
        .exec(&["chmod +x /entry.sh"])
        .expect("failed to make target");

    let args = [
        ("WORKSPACE", &*format!("{}/{}", env_parent, dockersnippets)),
        ("NAME", &lib_name),
    ];

    let env = args
        .into_iter()
        .map(|(x, y)| format!("{x}={y}"))
        .collect::<Vec<_>>()
        .join(" ");

    dbg!(
        container
            .exec(&[dbg!(format!("{env} /entry.sh"))])
            .expect("failed to make target")
    );

    loop {
        let output = dbg!(
            container
                .exec(&["ls", "-a", "target/debug"])
                .expect("failed to get output")
        );
        let output = container
            .exec(&[
                "RUSTFLAGS=\"-Awarnings\"",
                "cargo",
                "build",
                "--package",
                lib_name,
            ])
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
