use std::cell::UnsafeCell;

use super::{Handle, Meta, archetype::Archetype};

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

impl<'a> Table<'a> {
    pub fn with_archetype(archetype: Archetype) -> Self {
        let pages = UnsafeCell::new(vec![]);
        Self { archetype, pages }
    }

    pub fn pages(&'a self) -> impl Iterator<Item = &'a Page> + 'a {
        unsafe { self.pages.get().as_mut().unwrap() }.iter()
    }

    pub fn pages_mut(&'a self) -> impl Iterator<Item = &'a mut Page> + 'a {
        unsafe { self.pages.get().as_mut().unwrap() }.iter_mut()
    }

    pub fn entity(&self, mut idx: usize) -> Entity {
        self.pages()
            .find(|page| {
                let count = page.count();
                let chosen = idx < count;
                if !chosen {
                    idx -= count;
                }
                chosen
            })
            .map(|page| page.entity(idx))
            .expect("Index out of bounds")
    }
}
