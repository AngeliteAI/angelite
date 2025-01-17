#[fast::main]
async fn main() {
    println!("Hello, world!");
    unsafe { editor::editor_start() };
}
