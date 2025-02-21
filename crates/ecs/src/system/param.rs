use crate::component::{
    archetype::Archetype,
    registry::{Registry, Shard},
    table::Table,
};

use super::func::Outcome;

pub trait Param: Send {
    fn inject(archetype: &mut Archetype);
    fn create(archetype: Archetype, table: &mut Table) -> Self
    where
        Self: Sized;
}

pub trait Params: Send + 'static {
    fn bind(registry: &mut Registry) -> Shard;
    fn create(archetype: Archetype, table: Table) -> Self
    where
        Self: Sized;
}
use base::array;
ecs_macro::params!();

impl Param for () {
    fn inject(archetype: &mut Archetype) {
        todo!()
    }

    fn create(archetype: Archetype, table: &mut Table) -> Self
    where
        Self: Sized,
    {
        todo!()
    }
}
