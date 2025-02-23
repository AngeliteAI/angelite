use crate::component::{
    archetype::Archetype,
    registry::{Registry, Shard},
    table::Table,
};

use super::func::Outcome;
use std::cell::UnsafeCell;

pub trait Param<'a>: Send {
    fn inject(archetype: &mut Archetype);
    fn create(archetype: Archetype, table: &'a mut Table) -> Self
    where
        Self: Sized + 'a;
}

pub trait Params<'a>: Send + 'static {
    fn bind(registry: &mut Registry) -> Shard;
    fn create(archetype: Archetype, table: &'static mut Table) -> Self
    where
        Self: Sized + 'a;
}
use base::array;
ecs_macro::params!();

impl Param<'_> for () {
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
