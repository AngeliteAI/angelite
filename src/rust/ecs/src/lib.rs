#![feature(
    fn_traits,
    int_roundings,
    box_as_ptr,
    unboxed_closures,
    async_fn_traits,
    more_maybe_bounds,
    set_ptr_value
)]
#![feature(ptr_metadata)]

pub mod component;
pub mod entity;
pub mod query;
pub mod schedule;
pub mod system;
pub mod world;
