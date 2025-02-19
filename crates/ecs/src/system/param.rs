use crate::component::{
    archetype::Archetype, meta::Metashard, registry::Registry, table::Metatable,
};

use super::func::Outcome;

pub trait Param: Send {
    fn inject(archetype: &mut Archetype);
}

pub trait Params: Send + 'static {
    fn bind(registry: &mut Registry) -> Metashard;
    fn create(meta: Metashard) -> Self
    where
        Self: Sized;
}
use base::array;
ecs_macro::params!();

impl Param for i32 {
    fn inject(archetype: &mut Archetype) {
        todo!()
    }
}

impl Param for () {
    fn inject(archetype: &mut Archetype) {
        todo!()
    }
}

impl Param for (i32,) {
    fn inject(archetype: &mut Archetype) {
        todo!()
    }
}
