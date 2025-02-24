use std::mem;
use crate::component::{archetype::Archetype, table::Page};
use crate::component::source::Source;

#[derive(Debug)]
pub struct Entity {
    pub(crate) data: *mut u8,
    pub(crate) generation: usize,
}

impl Entity {
    pub(crate) fn new(data: *mut u8) -> Self {
        Self {
            data,
            generation: 0,
        }
    }

    pub(crate) fn archetype(&self) -> &Archetype {
        unsafe { self.head().cast::<Archetype>().as_ref().unwrap() }
    }

    pub(crate) fn data(&self) -> *mut u8 {
        self.data
    }

    pub(crate) fn head(&self) -> *mut u8 {
        let mut head = self.data as usize;
        head = head & !(Page::SIZE - 1);
        head as *mut u8
    }

    pub(crate) fn index(&self) -> usize {
        let data = self.data as usize;
        let head = self.head() as usize;
        (data - (head + mem::size_of::<Archetype>())) / self.archetype().size().max(1)
    }

    pub(crate) fn incr_gen(self) -> Self {
        Self {
            generation: self.generation + 1,
            data: self.data,
        }
    }
}
