#[cfg(target_os = "macos")]
pub mod macos;
#[cfg(target_os = "macos")]
pub use macos::editor_start;
use major::{
    system::{func::Provider, sequence::Sequence},
    world::World,
};

pub struct App {
    world: World,
}

impl App {
    fn schedule<S: Sequence<Marker>, Marker: Provider>(&mut self, sequence: S) {
        sequence.transform(self.world.graph());
    }
}
