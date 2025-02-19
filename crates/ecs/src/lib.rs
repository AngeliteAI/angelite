#![feature(
    fn_traits,
    int_roundings,
    box_as_ptr,
    unboxed_closures,
    async_fn_traits
)]
pub mod component;
pub mod entity;
pub mod query;
pub mod schedule;
pub mod system;
pub mod world;
