use std::{any::Any, mem, ptr, sync::Arc};

use super::{
    Component, Handle,
    archetype::Archetype,
    table::{Components, Data, Erase},
};
use base::array;
use base::collections::array::Array;
use base::prelude::W;
use base::rng::transform::DistributionTransform;

pub trait Source: 'static {
    type Table: ?Sized;
    unsafe fn erase_component_data<'a>(self) -> Components<'a>
    where
        Self: 'a + Sized;
    unsafe fn archetype(&self) -> Archetype;
}
ecs_macro::source!();
