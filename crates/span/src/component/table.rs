use std::cell::UnsafeCell;

use super::{Meta, archetype::Archetype};

pub struct Data {
    pub ptr: *mut [u8],
    pub meta: Meta,
}

pub struct Table<'a> {
    archetype: Archetype,
    pages: UnsafeCell<Vec<Page<'a>>>,
}

pub struct Page<'a> {
    head: *mut u8,
    capacity: usize,
    state: UnsafeCell<State<'a>>,
}

pub struct State<'a> {
    erased: Vec<Option<Handle<'a>>>,
    freed: Vec<*mut u8>,
}

impl Table<'_> {}
