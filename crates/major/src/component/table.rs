use core::fmt;
use std::{
    alloc,
    cell::UnsafeCell,
    iter,
    mem::{self, transmute},
};

use fast::collections::array::Array;

use crate::entity::Entity;

use super::{Handle, Meta, archetype::Archetype};

pub struct Data {
    pub ptr: *mut [u8],
    pub meta: Meta,
}

type Components = Array<Handle<'static>, { Archetype::MAX }>;

pub struct Table {
    archetype: Archetype,
    pages: UnsafeCell<Vec<Page>>,
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
        mut data: impl Iterator<Item = Components>,
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
        data: &mut dyn Iterator<Item = Components>,
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

    pub fn free(&self, buckets: Vec<Entity>) -> _ {
        let mut page_head = HashMap::default();

        entities.into_iter().for_each(|entity| {
            page_head.entry(entity.head()).or_default().push(entity)
        });

        let mut pages = unsafe { self.pages.get().as_mut().unwrap() };

        for (page_head, entities) in page_head {
            let page = pages.iter_mut().find(|page| page.head as usize == page_head).unwrap();

            page.free(entities);
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

    pub fn insert(&self, components: Array<Handle<'static>, { Archetype::MAX }>) -> Option<Entity> {
        let entity = self.state().freed.pop()?;
        let archetype = self.archetype();
        for (i, (component, meta)) in components.into_iter().zip(archetype.iter()).enumerate() {
            component.write_to(self.row_column(&entity, i), meta);
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

            erased[i].coalese(self.row_column(entity, i), meta);
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
