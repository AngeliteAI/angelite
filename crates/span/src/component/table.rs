use core::fmt;
use std::{alloc, cell::UnsafeCell, iter, mem};

use fast::collections::array::Array;

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
    erased: Vec<Option<Array<Handle<'a>, { Archetype::MAX }>>>,
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

impl<'a> fmt::Debug for Page<'a> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Page")
            .field("head", &self.head)
            .field("entities", &(self.count() / self.archetype().len()))
            .field("components", &self.count())
            .field("capacity", &self.capacity)
            .field("freed", &self.state.freed.len())
            .finish()
    }
}

impl<'a> Page<'a> {
    pub const SIZE: usize = 2usize.pow(14);
    pub const AVAIL: usize = Page::SIZE - mem::size_of::<Archetype>();

    pub fn new(archetype: Archetype) -> Self {
        let capacity = Self::capacity(&archetype);
        let row_size = archetype.size();
        let layout = alloc::Layout::from_size_align(Page::SIZE, Page::SIZE).unwrap();
        let mut head = unsafe { alloc::alloc(layout) };
        unsafe { head.cast::<Archetype>().write(archetype) };
        head = unsafe { head.add(mem::size_of::<Archetype>()) };
        Self {
            capacity,
            head,
            state: UnsafeCell::new(State::init(head, capacity, row_size)),
        }
    }

    pub fn capacity(archetype: &Archetype) -> usize {
        let row = archetype.size();
        Self::AVAIL.div_floor(row)
    }
}

impl State<'_> {
    fn init(head: *mut u8, capacity: usize, row_size: usize) -> Self {
        let freed = (0..capacity)
            .map(|i| unsafe { head.add(i * row_size) })
            .rev()
            .collect::<Vec<_>>();
        let erased = iter::repeat(None).take(capacity).collect();
        Self { freed, erased }
    }
}
