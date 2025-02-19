use core::fmt;
use std::{
    alloc,
    cell::UnsafeCell,
    collections::HashMap,
    iter,
    mem::{self, transmute},
    ptr, slice,
    sync::Arc,
};

use base::collections::{array::Array, arrayvec::ArrayVec};

use crate::entity::Entity;

use super::{Component, Handle, Meta, archetype::Archetype};

pub struct Data {
    pub ptr: *mut [u8],
    pub meta: Meta,
}
impl Data {
    pub fn copy_to(&mut self, src: *const u8, check: &Meta) {
        let Self { ptr, meta } = self;
        assert_eq!(meta, check);
        unsafe { ptr::copy(src, *ptr as *mut _, meta.size) };
    }
    pub fn copy_from(&self, dst: *mut u8, check: &Meta) {
        let Self { ptr, meta } = self;
        assert_eq!(meta, check);
        unsafe { ptr::copy(*ptr as *const _, dst, meta.size) }
    }
}

pub trait Erase {
    fn erase(self: &mut Arc<Self>) -> Data;
}

impl<C: Component> Erase for C {
    fn erase(self: &mut Arc<Self>) -> Data {
        let ptr = ptr::slice_from_raw_parts_mut(
            Arc::get_mut(self).unwrap() as *mut _ as *mut u8,
            mem::size_of::<C>(),
        );
        Data {
            ptr,
            meta: Meta::of::<C>(),
        }
    }
}

pub type Components<'a> = Array<(Handle<'a>, Data), { Archetype::MAX }>;

pub struct Table {
    archetype: Archetype,
    pub(crate) pages: UnsafeCell<Vec<Page>>,
}

pub struct Page {
    head: *mut u8,
    capacity: usize,
    state: UnsafeCell<State>,
}

pub struct State {
    erased: Vec<Option<Array<Handle<'static>, { Archetype::MAX }>>>,
    freed: Vec<Entity>,
}

impl Table {
    pub fn with_archetype(archetype: Archetype) -> Self {
        let pages = UnsafeCell::new(vec![]);
        Self { archetype, pages }
    }

    fn pages(&self) -> impl Iterator<Item = &Page> {
        unsafe { self.pages.get().as_mut().unwrap() }.iter()
    }

    fn pages_mut(&self) -> impl Iterator<Item = &mut Page> {
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

    pub fn extend(
        &self,
        mut data: impl Iterator<Item = Components<'static>>,
    ) -> impl Iterator<Item = Entity> {
        let mut entities = vec![];
        loop {
            let len = entities.len();
            let page_entities = self.extend_next_page(&mut data);
            entities.extend(page_entities);
            if entities.len() == len {
                break;
            }
        }
        entities.into_iter()
    }

    pub fn extend_next_page(
        &self,
        data: &mut dyn Iterator<Item = Components<'static>>,
    ) -> impl Iterator<Item = Entity> {
        let next_page = unsafe {
            let pages = self.pages.get().as_mut().unwrap();
            &mut pages[self.next_page_index()]
        };
        let mut entities = vec![];
        while next_page.can_insert() {
            let components = data.next().unwrap();
            let entity = next_page.insert(components).unwrap();
            entities.push(entity);
        }
        entities.into_iter()
    }

    pub fn next_page_index(&self) -> usize {
        let pages = unsafe { self.pages.get().as_mut().unwrap() };
        if pages.is_empty() || pages.last().unwrap().is_full() {
            pages.push(Page::new(self.archetype.clone()));
            return pages.len() - 1;
        }
        for (i, page) in pages.iter().enumerate() {
            if !page.is_full() {
                return i;
            }
        }
        unreachable!("No available pages?");
    }

    pub fn free(&self, entities: Vec<Entity>) {
        type Head = *mut u8;
        let mut page_head = HashMap::<Head, Vec<Entity>>::default();

        entities
            .into_iter()
            .for_each(|entity| page_head.entry(entity.head()).or_default().push(entity));

        let mut pages = unsafe { self.pages.get().as_mut().unwrap() };

        for (page_head, entities) in page_head {
            let page = pages
                .iter_mut()
                .find(|page| page.head == page_head)
                .unwrap();

            page.free(entities);
        }
    }
}

impl fmt::Debug for Page {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Page")
            .field("head", &self.head)
            .field("entities", &(self.count() / self.archetype().len()))
            .field("components", &self.count())
            .field("capacity", &self.capacity)
            .field("freed", &self.state().freed.len())
            .finish()
    }
}

impl Page {
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

    pub fn head(&self) -> *mut u8 {
        self.head
    }

    pub fn capacity(archetype: &Archetype) -> usize {
        let row = archetype.size();
        Self::AVAIL.div_floor(row)
    }

    pub fn count(&self) -> usize {
        Self::capacity(self.archetype()) - self.state().freed.len()
    }

    pub fn state(&self) -> &mut State {
        unsafe { self.state.get().as_mut().unwrap() }
    }

    pub fn is_full(&self) -> bool {
        self.state().freed.is_empty() && self.count() == self.capacity
    }

    pub fn entity(&self, index: usize) -> Entity {
        let row_size = self.archetype().size();
        let offset = index * row_size;
        let ptr = unsafe { self.head.add(offset) };
        Entity::new(ptr)
    }

    pub fn insert(&self, components: Components) -> Option<Entity> {
        let entity = self.state().freed.pop()?;
        let archetype = self.archetype();
        for (i, ((_handle, mut erased), meta)) in
            components.into_iter().zip(archetype.iter()).enumerate()
        {
            erased.copy_to(self.row_column(&entity, i), meta);
        }
        Some(entity)
    }

    pub fn free(&self, entities: impl IntoIterator<Item = Entity>) {
        for entity in entities {
            self.coalese_row(&entity);
            self.state().erased[entity.index()] = None;
            self.state().freed.push(entity.incr_gen());
        }
    }

    pub fn coalese_row(&self, entity: &Entity) {
        let idx = entity.index();
        for (i, meta) in self.archetype().iter().enumerate() {
            let Some(erased) = &mut self.state().erased[idx] else {
                unreachable!();
            };
            let data = Data {
                ptr: ptr::slice_from_raw_parts_mut(self.row_column(entity, i), meta.size),
                meta: *meta,
            };
            data.copy_from(erased[i].as_mut_ptr(), meta);
        }
    }

    pub fn row_column(&self, entity: &Entity, index: usize) -> *mut u8 {
        unsafe { entity.data.add(self.archetype().offset_of(index)) }
    }

    pub fn archetype(&self) -> &Archetype {
        unsafe { self.head.cast::<Archetype>().as_ref().unwrap() }
    }

    fn can_insert(&self) -> bool {
        self.state().freed.len() > 0 && self.count() + 1 <= self.capacity
    }
}

impl State {
    fn init(head: *mut u8, capacity: usize, row_size: usize) -> Self {
        let freed = (0..capacity)
            .map(|i| unsafe { head.add(i * row_size) })
            .map(Entity::new)
            .rev()
            .collect::<Vec<_>>();
        let erased = iter::repeat_with(|| None).take(capacity).collect();
        Self { freed, erased }
    }
}
