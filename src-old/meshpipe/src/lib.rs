#[cfg(target_os = "macos")]
pub mod macos;
use ecs::{
    system::{func::Provider, sequence::Sequence},
    world::World,
};
#[cfg(target_os = "macos")]
pub use macos::editor_start;

pub struct App {
    world: World,
}

impl App {
    fn schedule<S: Sequence<Marker>, Marker: Provider>(&mut self, sequence: S) {}
}
