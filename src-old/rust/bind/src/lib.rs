#![feature(
    unboxed_closures,
    trait_alias,
    coroutines,
    stmt_expr_attributes,
    coroutine_trait
)]
use docker::{CommandResult, Container, Docker, Image, container_config};
use gemini::{GeminiClient, GeminiError};
use serde::Deserialize;
use std::{
    cell::{OnceCell, RefCell, UnsafeCell}, collections::HashMap, env, fs, ops::{ControlFlow, Coroutine, CoroutineState}, os::unix::process::ExitStatusExt, path::{Path, PathBuf}, pin::{pin, Pin}, process::Command, rc::Rc, sync::{Arc, OnceLock}, thread::{self, current}, time::{Duration, SystemTime}
};

mod container;

pub trait ContainerExt {
    fn inject(&self, script: impl AsRef<str>) -> Script;
}

impl ContainerExt for Container {
    fn inject(&self, script: impl AsRef<str>) -> Script {
        let script_content = script.as_ref();

        // Ask the container for a temporary file path
        let temp_path_output = self
            .exec(&["mktemp", "-d"])
            .expect("Failed to create temporary file in container");

        // Parse the output to get the path (mktemp outputs the created path)
        let temp_path_str = temp_path_output.stdout.trim();
        let mut script_path = PathBuf::from(temp_path_str);

        // Write the script content to the file
        let hosttemp = env::temp_dir().join("script.sh");
        std::fs::write(&hosttemp, script_content).expect("Failed to write script to container");
        self.copy_to(hosttemp.to_str().unwrap(), script_path.to_str().unwrap())
            .unwrap();

        // Create a temporary file for the script
        script_path.push("script.sh"); // Or another appropriate name

        Script {
            container: self,
            script_path,
        }
    }
}

#[derive(Deserialize, Debug)]
pub enum Invalid {
    User,
    Agent,
}

#[derive(Deserialize, Debug)]
#[serde(tag = "type")]
pub enum Error {
    Missing { path: PathBuf },
    Invalid { src: Invalid, msg: String },
}

#[derive(Debug, Clone, Copy)]
pub enum Language {
    Rust,
    Zig,
    Swift,
}

pub struct Output {
    pub lib_path: PathBuf,
    pub crate_name: String,
}

#[derive(Clone)]
pub struct Config {
    pub source: PathBuf,
    pub target: PathBuf,
    pub external_prompt: Option<String>,
}

static CTX: OnceLock<Context> = OnceLock::new();

pub struct Gemini {
    client: RefCell<GeminiClient>,
    temperature: f32,
    system: String,
}
impl Gemini {
    fn client(temperature: f32) -> GeminiClient {
        GeminiClient::new("gemini-2.0-flash-thinking-exp")
            .with_temperature(temperature)
            .with_api_key(&*env::var("GEMINI_API_KEY").unwrap())
    }
}

pub trait ResponseCoroutine =
    std::ops::Coroutine<(), Yield = Result<String, GeminiError>, Return = Result<(), GeminiError>>;
impl Model for Gemini {
    fn new(system: String, temperature: f32) -> Self {
        Self {
            client: Self::client(temperature).into(),
            temperature,
            system,
        }
    }

    fn temp(&self) -> f32 {
        self.temperature
    }
    fn respond(&self, prompt: String) -> Pin<Box<dyn ResponseCoroutine + '_>> {
        // Clone what we need for the coroutine
        let prompt_clone = prompt;

        // Keep reference to client
        let client = &self.client;

        Box::pin(
            #[coroutine]
            static move || {
                let max_retries = 3;
                let mut retries = 0;

                loop {
                    // Get a streaming coroutine for this attempt
                    let mut stream_coroutine = client
                        .borrow_mut()
                        .generate_content_streaming(&prompt_clone);
                    let mut pinned = unsafe { Pin::new_unchecked(&mut *stream_coroutine) };

                    // Track any errors during streaming
                    let mut had_error = false;

                    // Process all yields from the streaming coroutine
                    loop {
                        match pinned.as_mut().resume(()) {
                            std::ops::CoroutineState::Yielded(result) => {
                                // Check for errors
                                if let Err(_) = &result {
                                    had_error = true;
                                }

                                // Forward the result to our caller
                                yield result;
                            }
                            std::ops::CoroutineState::Complete(final_result) => {
                                match final_result {
                                    Ok(()) => {
                                        // Stream completed successfully without errors
                                        if !had_error {
                                            return Ok(());
                                        }

                                        // Had errors during streaming - check if we should retry
                                        break;
                                    }
                                    Err(e) => {
                                        // Check if this is a network error (curl exit code 56)
                                        let is_network_error = match &e {
                                            GeminiError::HttpError(msg) => {
                                                msg.contains("exit code: 56")
                                            }
                                            _ => false,
                                        };

                                        if is_network_error && retries < max_retries {
                                            // Break out to retry
                                            break;
                                        }

                                        // Non-retryable error or max retries exceeded
                                        return Err(e);
                                    }
                                }
                            }
                        }
                    }

                    // If we get here, we either need to retry or had errors
                    if retries < max_retries {
                        // Wait before retrying
                        std::thread::sleep(std::time::Duration::from_secs(2));
                        retries += 1;

                        // Inform the user we're retrying
                        yield Ok(format!(
                            "Network error, retrying ({}/{})",
                            retries, max_retries
                        ));
                        continue;
                    }

                    // If we get here, we've exhausted our retries
                    return Ok(());
                }
            },
        )
    }
    fn change(&self, temp: f32) {
        *self.client.borrow_mut() = Self::client(temp as f32);
    }
}
///Provides AI responses
pub trait Model {
    fn new(system: String, temperature: f32) -> Self
    where
        Self: Sized;
    fn respond(&self, prompt: String) -> Pin<Box<dyn ResponseCoroutine + '_>>;
    fn change(&self, temp: f32);
    fn temp(&self) -> f32;
}

pub struct Prompter<M: Model> {
    model: Rc<M>,
}
impl<M: Model> Prompter<M> {
    fn from_model(model: Rc<M>) -> Self {
        Self { model }
    }

    fn generate_bindings(
        &self,
        c_abi: &[(PathBuf, String)],
        injection: &str,
        target_guidelines: &str,
        input_lang: &Language,
        output_lang: &Language,
    ) -> String {
        const BINDING_GUIDELINES: &str = include_str!("generate_bindings.prompt");
        const YES: &str = "YES";
        const NO: &str = "NO";

        let mut tries = 0;
        let mut buffer = String::new();

        let mut buffer_critique = String::new();
        'outer: loop {
            tries += 1;
            let mut buffer_main = String::new();
            let mut buffer_main_cursor = 0;
            let mut critique_requested = false;
            // Run the first part of generation
            let mut prompt = String::new();

            let mut temp = self.model.temp();

            let mut prompt = String::new();
            prompt.push_str(BINDING_GUIDELINES);
            prompt.push_str("\n\n# Binding target guidelines\n\n");
            prompt.push_str(target_guidelines);
            prompt.push_str("\n\n# Generation parameters\n");
            prompt.push_str(&format!("Current temperature: {temp}\n"));
            prompt.push_str(&format!("Input Language: {input_lang:?}\nOutput Language: {output_lang:?}\n\n"));
            prompt.push_str(&format!("# C-abi input\n\n{c_abi:?}\n\n"));
            
            if !injection.is_empty() {
                prompt.push_str(&format!(
                    "# Compiler output:\n```\n{injection}\n```\n\n"
                ));
            }
            else {
                prompt.push_str("# No compiler output provided\n");
            }

            if !buffer_critique.is_empty() {
                prompt.push_str(&format!(
                    "# AI feedback on previous output:\n```\n{buffer_critique}\n```\n\n"
                ));
            }

            if !buffer.is_empty() {
                prompt.push_str(&format!(
                    "# IMPORTANT: This is the code the critique is about: \n\n{buffer}\n"
                ));
            }

            println!("{prompt}");
            let mut main_coroutine = pin!(self.model.respond(prompt));
            let mut yes = true;
            let mut ready = true;
            println!("going into loop");
            while yes {
                println!("top");
                while ready {
                    //}&& buffer_main.len() - buffer_main_cursor < 4096 {
                    match main_coroutine.as_mut().resume(()) {
                        CoroutineState::Complete(complete) => {
                            println!("yo123123");
                            complete.unwrap();
                            ready = false;
                        }
                        CoroutineState::Yielded(yielded) => {
                            let yielded = yielded.unwrap();
                            println!("cargo::warning={yielded}");
                            buffer_main += &yielded;
                        }
                    }
                }
                println!("out");

                buffer = buffer_main.clone();

                let prompt = format!(
                    "You are a specialized code binding evaluator. Your task is to assess if generated code bindings match the provided style guide with extreme precision.
When evaluating the code:

IMPORTANT: Output a number, and only a number, one number with no other symbols, including code (THERE SHOULD BE NO CODE OR WORDS OR ANYTHING).
Just output a number between 0 and 100 that represents how closely the code follows the binding guidelines (a percentage, but without the %)

Everything below this line is the bind guidelines you were asked to use:
````
{BINDING_GUIDELINES}
{target_guidelines}
````

Here is compiler output:
{injection}

Everything below this line is the code you were asked to evaluate:

{buffer_main}"
                );

                let mut eval_coroutine = pin!(self.model.respond(prompt));

                let mut buffer_eval = String::new();

                while let CoroutineState::Yielded(yielded) = eval_coroutine.as_mut().resume(()) {
                    buffer_eval += &yielded.unwrap();
                }

                dbg!(&buffer_eval, &buffer_critique);

                println!("cargo::warning=\n\n\n\n EVAL \n\n\n\n");
                let critical = 85;
                println!(
                    "cargo::warning=\n\nVALUE: {}\nCRITICAL THRESHOLD: {critical}\n",
                    buffer_eval
                );
                let val = buffer_eval.trim().parse::<usize>().unwrap();

                yes = val >= critical;

                if !yes {
                    println!("\n\n\n\n CRITIQUE \n\n\n\n");

                    let prompt = format!(
                    "You are a specialized code binding evaluator. Your task is to assess if generated code bindings match the provided style guide with extreme precision.
When evaluating the code:

Categorize each guideline as either \"critical\" or \"non-critical\" based on importance
Consider a binding successful only if 100% of critical guidelines and at least 95% of non-critical guidelines are met
Focus on style conformance, not functionality
Be aware the code may be incomplete as it's being generated in real-time
IMPORTANT: Do not output code! You are being asked to create a categorized list of critiques. Only output your list of critiques, and nothing else. Do not output anything else.

Everything below this line is the bind guidelines you were asked to use:
{BINDING_GUIDELINES}
{target_guidelines}

Here is compiler output:
{injection}

Everything below this line is the code you were asked to evaluate:

{buffer_main}"
                );

                    let mut critique_coroutine = pin!(self.model.respond(prompt));

                    while let CoroutineState::Yielded(yielded) =
                        critique_coroutine.as_mut().resume(())
                    {
                        let yielded = yielded.unwrap();
                        println!("cargo::warning={yielded}");
                        buffer_critique += &yielded;
                    }

                    let prompt = format!(
                    "You are a specialized bind generator. You failed to provide code that met the critical threshold of {critical}, instead, your code scored {val}. You have currently been set to temperature {temp} and are being asked to provide a new temperature to try. Only output a temperature between 0.0 - 1.0 where 0.0 is very strict and 1.0 is very creative. Do not output anything else.

Here are the binding guidelines you were asked to use:
{BINDING_GUIDELINES}
{target_guidelines}

Here is compiler output:
{injection}

Here is the critique about your code:
{buffer_critique}

Here is the current code:

{buffer_main}"
                );

                    let mut temp_coroutine = pin!(self.model.respond(prompt));

                    let mut buffer_temp = String::new();

                    while let CoroutineState::Yielded(yielded) = temp_coroutine.as_mut().resume(())
                    {
                        buffer_temp += &yielded.unwrap();
                    }

                    temp = buffer_temp.trim().parse::<f32>().unwrap();
                    self.model.change(temp);
                    println!("cargo::warning=Changed temperature to {}", temp);

                    continue;
                }

                if !ready {
                    break 'outer buffer;
                }
            }
        }
    }
}

///Interprets AI responses
pub struct Interpreter<M: Model> {
    model: Rc<M>,
}
impl<M: Model> Interpreter<M> {
    fn from_model(model: Rc<M>) -> Self {
        Self { model }
    }

    fn error_interpret(&self, err: String) -> Option<Vec<Error>> {
        let mut ret = String::new();
        let mut coroutine = pin!(
            self.model
                .respond(format!("{}\n{err}", include_str!("error_interpret.prompt")),)
        );

        let mut ret = String::new();

        while let CoroutineState::Yielded(text) = coroutine.as_mut().resume(()) {
            ret += &text.unwrap();
        }

        dbg!(serde_json::from_str(dbg!(
            ret.trim_matches('`').trim_start_matches("json").trim()
        )))
        .ok()
    }
}

///Represents a stage of work
pub trait Stage {
    fn priority(&self) -> u64 {
        500
    }
    fn installation<'a>(&self, container: &'a Container) -> Script<'a>;
}

pub trait Provider {
    fn language() -> Language where Self: Sized;
    fn derive() -> Self where Self: Sized;
    fn setup(&self) -> Vec<Arc<dyn Stage>>;
    fn file_ext(&self) -> &'static str;
    fn find_files(&self, container: &Container, path: &Path) -> Result<Vec<PathBuf>, String> {
        let path_str = path.display().to_string();
        let glob = format!("*.{}", self.file_ext());
        let find_args = vec!["find", &path_str, "-name", &glob, "-type", "f"];
        println!("Executing find command: {:?}", find_args);
        let result = dbg!(container.exec(&find_args).unwrap());

        if !result.success {
            return Err(result.stderr);
        }

        // Parse the output to get all swift file paths
        let swift_file_paths: Vec<String> = result
            .stdout
            .lines()
            .map(|line| line.trim().to_string())
            .filter(|line| !line.is_empty())
            .collect();

        // Add all found swift files to args
        Ok(swift_file_paths.iter().map(|s| s.into()).collect())
    }
}

pub trait Compiler: Provider {
    fn compile(&self, pkg: &str, path: &Path) -> Result<String, String>;
    fn guidelines(&self) -> &'static str;
}

pub trait Applicator: Compiler {
    fn apply(&self, output: &Output, bindings: String);
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
    fn file_ext(&self) -> &'static str {
        "zig"
    }
    
    fn language() -> Language where Self: Sized {
    Language::Zig
    }
    
    fn derive() -> Self where Self: Sized {
    Zig
    }
}

pub struct Rust;

pub struct RustInstall;

impl Stage for RustInstall {
    fn installation<'a>(&self, container: &'a Container) -> Script<'a> {
        container.inject(include_str!("install_rust.sh").to_owned())
    }
}
impl Provider for Rust {
    fn setup(&self) -> Vec<Arc<dyn Stage>> {
        vec![Arc::new(RustInstall)]
    }
    fn file_ext(&self) -> &'static str {
        "rs"
    }
    
    fn language() -> Language where Self: Sized {
    Language::Rust
    }
    
    fn derive() -> Self where Self: Sized {
    Rust
    }
}
impl Compiler for Rust {
    fn compile(&self, pkg: &str, path: &Path) -> Result<String, String> {
        match Command::new("cargo").args(&["build", "--release", "--package", &pkg]).current_dir(path).output() {
            Ok(out) => if out.status.success() {
Ok(String::from_utf8_lossy(&out.stdout).to_string())
            }  else {
Err(String::from_utf8_lossy(&out.stderr).to_string())
            },
            Err(err) => panic!("{err:?}"),
        }
    }

    fn guidelines(&self) -> &'static str {
        include_str!("generate_bindings_rust.prompt")
    }
}

impl Applicator for Rust {
    fn apply(&self, output: &Output, bindings: String) {
    let sys_name = format!("{}-sys", output.crate_name);
    let _ = Command::new("rm")
        .args(["-rf", &sys_name])
        .current_dir(&output.lib_path)
        .output();
    let _ = Command::new("cargo")
        .args(["new", "--lib", &sys_name])
        .current_dir(&output.lib_path)
        .output();
    println!("cargo::warning={:?}", &bindings);
    // Split the bindings by ```rust markers
    let code_blocks: Vec<&str> = bindings.split("```rust").collect();
    println!("cargo::warning={:?}", &code_blocks);
    // Create a map to store path -> code mappings
    let mut path_code_map: HashMap<PathBuf, String> = HashMap::new();
    
    // Process each code block - skip the first element as it's likely empty or contains non-code text
    for block in code_blocks.iter().skip(1) {
        // Find the end of the code block
        if let Some(end_index) = block.find("```") {
            let full_block = &block[..end_index].trim();
            let mut lines = full_block.lines();
            
            // The first line might be a path or a comment containing a path
            if let Some(first_line) = lines.next() {
                let path_str = if first_line.trim().starts_with("//") {
                    // Extract path from comment
                    first_line.trim().trim_start_matches("//").trim()
                } else {
                    // Might be a direct path
                    first_line.trim()
                };
                
                // Check if this looks like a valid path
                if path_str.contains("/") || path_str.contains(".") {
                    // This is likely a path
                    let rel_path = PathBuf::from(path_str);
                    
                    // The rest of the lines are the code
                    let code = lines.collect::<Vec<&str>>().join("\n");
                    
                    // Store in our map
                    path_code_map.insert(rel_path.clone(), code.clone());
                    
                } else {
                    // No path found, but we still have code
                    println!("cargo::warning=Code block without path information: {}", first_line);
                }
            }
        }
    }
    
    // Now write each code block to its respective file
    for (rel_path, code) in path_code_map.iter() {
        // Construct the full path
        let full_path = output.lib_path.join(&sys_name).join(rel_path);
        
        // Create parent directories if needed
        if let Some(parent) = full_path.parent() {
            fs::create_dir_all(parent).expect("Failed to create directory structure");
        }
        
        // Write the code to the file
        fs::write(&full_path, code).expect("Failed to write to file");
        println!("cargo::warning=Written code to {}", rel_path.display());
    
    }
}

}
pub struct Swift;
pub struct SwiftInstall;

impl Stage for SwiftInstall {
    fn priority(&self) -> u64 {
        10
    }
    fn installation<'a>(&self, container: &'a Container) -> Script<'a> {
        container.inject(include_str!("install_swift.sh").to_owned())
    }
}

impl Provider for Swift {
    fn setup(&self) -> Vec<Arc<dyn Stage>> {
        vec![Arc::new(SwiftInstall)]
    }
    fn file_ext(&self) -> &'static str {
        "swift"
    }
    
    fn language() -> Language where Self: Sized {
    Language::Swift
    }
    
    fn derive() -> Self where Self: Sized {
    Swift
    }
}

impl Compiler for Swift {
    fn compile(&self, pkg: &str, path: &Path) -> Result<String, String> {
        let mut args = vec!["swiftc".to_owned()];
        /*let files = self
            .find_files(container, path)
            .unwrap()
            .into_iter()
            .map(|s| s.to_str().map(ToOwned::to_owned).unwrap())
            .collect::<Vec<_>>();
        args.extend(files);
        args.push("-parse-as-library".to_owned());
        args.push("-o Hello".to_owned());
        let ret = dbg!(container.exec(&args).unwrap());*/
        let files = todo!();
        let ret = todo!();
        match ret {
            CommandResult {
                success: true,
                stdout,
                stderr,
                exit_code,
            } => Ok(stdout),
            CommandResult {
                success: false,
                stdout,
                stderr,
                exit_code,
            } => Err(stderr),
        }
    }

    fn guidelines(&self) -> &'static str {
        include_str!("generate_bindings_swift.prompt")
    }
}

pub struct Context {
    temp: PathBuf,
}

pub struct Build {
    container: Container,
    source: Arc<dyn Provider>,
    target: Arc<dyn Compiler>,
}

pub struct Script<'a> {
    container: &'a Container,
    script_path: PathBuf,
}

impl Script<'_> {
    fn run(&self) -> CommandResult {
        let path = self.script_path.to_str().unwrap();
        self.container.exec(&["chmod", "+x", path]).unwrap();
        self.container
            .exec(&["/bin/bash", "-c", &*format!("{}", path)])
            .unwrap()
    }
}

impl Build {
    fn source_files(&self, path: impl AsRef<Path>) -> Result<Vec<PathBuf>, String> {
        dbg!(self.source.find_files(&self.container, path.as_ref()))
    }

    fn create(src_lang: Language, dst_lang: Language) -> Build {
        let existed;
        let container = {
            let name = format!("Build_BindAI_{:?}_{:?}", src_lang, dst_lang);
            let mut container = if Docker::container_exists(&name) {
                existed = true;
                Docker::container(&name)
            } else {
                existed = false;
                let container_config = container_config()
                    .working_dir(env::current_dir().unwrap().to_str().unwrap())
                    .cmd(vec!["sleep", "300"]);
                let mut image = Image::new("ubuntu", "latest");
                image.pull().unwrap();
                image
                    .create_container(&name, &container_config.build())
                    .unwrap()
            };
            container.refresh().unwrap();
            if !container.running() {
                dbg!(container.start().unwrap());
            }
            container
        };

        let source = Arc::new(match src_lang {
            Language::Zig => Zig,
            _ => todo!(),
        }) as Arc<dyn Provider>;

        let target = match dst_lang {
            Language::Swift => Arc::new(Swift) as Arc<dyn Compiler>,
            Language::Rust => Arc::new(Rust) as Arc<dyn Compiler>,
            _ => todo!(),
        };

        let mut stages = vec![];

        stages.extend(source.setup());
        stages.extend(target.setup());

        stages.sort_by_key(|x| x.priority());

        if !existed {
            for stage in stages {
                dbg!("Installing stage...");
                let CommandResult {
                    success,
                    mut stdout,
                    stderr,
                    exit_code,
                } = stage.installation(&container).run();
                {
                    let out = if success {
                        stdout
                    } else {
                        stdout.push_str(&stderr);
                        stdout
                    };
                    println!("Exited with code {exit_code}: {out}");
                }
            }
        }

        Self {
            container,
            source,
            target,
        }
    }

    fn include(&self, host_path: impl AsRef<Path>) {
        let path_str = host_path.as_ref().to_str().unwrap();
        let parent_path_str = host_path.as_ref().parent().unwrap().to_str().unwrap();
        self.container
            .exec(&["mkdir", "-p", parent_path_str])
            .expect("failed to create host directory in container");

        self.container
            .copy_to(path_str, path_str)
            .expect("failed to mount and copy host data");
    }

}

pub fn bind<Source: Provider, Target: Compiler>(cfg: &Config) -> String {
    let Config {
        source: src_dir,
        target: bind_dir,
    ..
    } = cfg;

    let build = Build::create(Source::language(), Target::language());
    let model = Rc::new(Gemini::new("".to_owned(), 0.5));
    let interpreter = Interpreter::from_model(model.clone());
    let prompter = Prompter::from_model(model.clone());
    let error_act = |err| match interpreter.error_interpret(err) {
        Some(errs) => {
            for err in errs {
                match err {
                    Error::Missing { path } => {
                        build.include(path.to_str().unwrap());
                    }
                    _ => todo!(),
                }
            }
        }
        None => println!("no error found?"),
    };
    loop {
        let src_file_paths = match build.source_files(&src_dir) {
            Ok(x) => dbg!(x),
            Err(e) => {
                (error_act)(e);
                continue;
            }
        };
        let mut src_files = vec![];

        for path in src_file_paths {
            src_files.push((path.to_owned(), fs::read_to_string(&path).unwrap()));
        }

        //temporarily disable compile/looping unction
        break prompter.generate_bindings(
            &src_files,
          &  cfg.external_prompt.clone().unwrap_or_default(),
            build.target.guidelines(),
            &Source::language(),
            &Target::language(),
        );


        //match build.compile(&bind_dir) {
        //    Ok(out) => todo!(),
        //    Err(err) => {
        //        error_act(err);
        //        continue;
        //    }
        //}
    }
}

pub fn bind_and_verify<Source: Provider, Target: Applicator>(cfg: &Config, output: &Output) {
    let mut buffer = None;
    loop {
        let bindings = bind::<Source, Target>(&Config {
            external_prompt: buffer.clone(),
            ..cfg.clone()
        });
        let target = Target::derive();
        target.apply(&output, bindings.clone());
        match target.compile( &output.crate_name, &output.lib_path) {
            Ok(out) => {
                break;
            }
            Err(err) => {
                println!("\n\n\n{:?}\n\n\n", err);
                buffer = Some(format!("These bindings\n```{bindings}```\n were deemed acceptable by the guidelines, but generated these compiler errors:\n```{err}```\nPlease fix the bindings as provided and improve upon them based on compiler feedback"));
            }
        }
    }
}

use regex::Regex;

pub fn unescape_unicode(text: &str) -> String {
    // Create a regex pattern for Unicode escape sequences (\uXXXX)
    let unicode_pattern = Regex::new(r"\\u([0-9a-fA-F]{4})").unwrap();

    // Replace all matches with their corresponding characters
    let mut result = text.to_string();
    while let Some(caps) = unicode_pattern.captures(&result) {
        if let (Some(full_match), Some(hex_digits)) = (caps.get(0), caps.get(1)) {
            // Parse the hex digits into a Unicode code point
            if let Ok(code_point) = u32::from_str_radix(hex_digits.as_str(), 16) {
                // Convert the code point to a character
                if let Some(ch) = std::char::from_u32(code_point) {
                    // Replace the escape sequence with the actual character
                    result = result.replacen(full_match.as_str(), &ch.to_string(), 1);
                    continue;
                }
            }
            // If parsing failed, leave it as is
        }
        break;
    }

    // Also handle other common escape sequences
    result = result
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\");

    result
}