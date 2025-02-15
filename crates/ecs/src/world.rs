use crate::{
    component::{
        archetype::{self, Archetype},
        table::Metatable,
    },
    system::graph::Graph,
};

pub struct World {
    graph: Graph,
}

impl World {
    pub fn graph(&mut self) -> &mut Graph {
        &mut self.graph
    }

    pub fn supertype(&mut self, archetype: Archetype) -> Metatable {
        todo!()
    }
}
