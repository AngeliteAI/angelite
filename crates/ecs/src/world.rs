use crate::{
    component::{
        archetype::{self, Archetype},
        registry::Registry,
        source::Source,
        table::Metatable,
    },
    system::{
        func::{Provider, Wrap},
        graph::Graph,
        sequence::Sequence,
    },
};

#[derive(Default)]
pub struct World {
    pub(crate) registry: Registry,
}

impl World {
    pub fn new() -> Self {
        Self {
            registry: Registry::default(),
        }
    }

    pub fn extend(&mut self, src: impl IntoIterator<Item = impl Source>) {
        self.registry.extend(src);
    }
}
