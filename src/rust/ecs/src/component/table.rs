use super::{Component, Handle, Meta, archetype::Archetype};
use crate::component::source::Source;
use crate::entity::Entity;
use base::array;
use base::collections::{array::Array, arrayvec::ArrayVec};
use base::rng::transform::DistributionTransform;
use core::fmt;
use std::fmt::{Formatter, format};
use std::{
    alloc,
    cell::UnsafeCell,
    collections::HashMap,
    iter,
    mem::{self, transmute},
    ptr, slice,
    sync::Arc,
};

pub struct Data {
    pub ptr: *mut u8,
    pub meta: Meta,
}
impl Data {
    pub fn copy_from(&mut self, src: *const u8, check: &Meta) {
        let Self { ptr, meta } = self;
        assert_eq!(meta, check);
        unsafe { ptr::copy(src, *ptr as *mut _, meta.size) };
    }
    pub fn copy_to(&self, dst: *mut u8, check: &Meta) {
        let Self { ptr, meta } = self;
        assert_eq!(meta, check);
        unsafe { ptr::copy(*ptr as *const _, dst, meta.size) }
    }
}

pub trait Erase {
    fn erase(self: Box<Self>) -> (Box<Self>, Data);
}

impl<C: Component> Erase for C {
    fn erase(self: Box<Self>) -> (Box<Self>, Data) {
        let orig = Box::into_raw(self);
        let ptr = ptr::slice_from_raw_parts(orig, mem::size_of::<C>());

        unsafe {
            (Box::from_raw(orig), Data {
                //SAFETY illegal hack
                ptr: ptr as *mut _,
                meta: Meta::of::<C>(),
            })
        }
    }
}

pub type Components<'a> = Vec<(Handle, Data)>;

pub struct Table {
    archetype: Archetype,
    pub(crate) pages: UnsafeCell<Vec<Page>>,
}

impl fmt::Debug for Table {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        let mut yes = f.debug_struct("Table");
        yes.field("archetype", &self.archetype);
        for (i, page) in unsafe { self.pages.get().as_mut().unwrap() }
            .iter()
            .enumerate()
        {
            yes.field(&i.to_string(), page);
        }
        yes.finish()
    }
}

pub struct Page {
    head: *mut u8,
    capacity: usize,
    state: UnsafeCell<State>,
}

#[derive(Debug)]
pub struct State {
    erased: Vec<Option<Array<Handle, { Archetype::MAX }>>>,
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

    pub fn handle(&self, mut idx: usize, component: usize) -> &Handle {
        self.pages()
            .find(|page| {
                let count = page.count();
                let chosen = idx < count;
                if !chosen {
                    idx -= count;
                }
                chosen
            })
            .map(|page| page.handle(idx, component))
            .expect("Index out of bounds")
    }

    pub fn entity(&self, mut idx: usize) -> Option<Entity> {
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
            let Some(components) = data.next() else {
                break;
            };
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
    pub fn count(&self) -> usize {
        let pages = unsafe { self.pages.get().as_mut().unwrap() };
        match pages.len() {
            0 => 0,
            1 => dbg!(pages.first().unwrap().count()),
            x => (x - 1) * Page::capacity(&self.archetype) + pages.last().as_ref().unwrap().count(),
        }
    }
}

impl fmt::Debug for Page {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        f.debug_struct("Page")
            .field("head", &self.head)
            .field(
                "entities",
                &(if self.archetype().len() == 0 {
                    0
                } else {
                    self.count() / self.archetype().len()
                }),
            )
            .field("components", &self.count())
            .field("capacity", &Self::capacity(&self.archetype()))
            .field("freed", &self.state().freed.len())
            .finish()
    }
}

impl Page {
    pub const SIZE: usize = 2usize.pow(14);
    pub const AVAIL: usize = Page::SIZE - mem::size_of::<Archetype>();

    pub fn new(archetype: Archetype) -> Self {
        let capacity = Self::capacity(&archetype);
        let row_size = archetype.size().max(1);
        let layout = alloc::Layout::from_size_align(Page::SIZE, Page::SIZE).unwrap();
        let mut head = unsafe { alloc::alloc(layout) };
        unsafe { head.cast::<Archetype>().write(archetype) };
        unsafe {
            Self {
                capacity,
                head,
                state: UnsafeCell::new(State::init(
                    head.add(mem::size_of::<Archetype>()),
                    capacity,
                    row_size,
                )),
            }
        }
    }

    pub fn capacity(archetype: &Archetype) -> usize {
        let row = archetype.size().max(1);
        Self::AVAIL.div_floor(row)
    }

    pub fn count(&self) -> usize {
        (Self::capacity(self.archetype())) - (self.state().freed.len())
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
        let ptr = unsafe { self.entity_head().add(offset) };
        Entity::new(ptr)
    }

    pub fn handle(&self, index: usize, component: usize) -> &Handle {
        &self.state().erased[(index)].as_ref().unwrap()[component]
    }

    pub fn insert(&self, components: Components<'static>) -> Option<Entity> {
        let entity = self.state().freed.pop()?;
        self.state().erased[entity.index()] = Some(Array::new());
        let archetype = self.archetype();
        for (i, ((_handle, mut erased), meta)) in
            components.into_iter().zip(archetype.iter()).enumerate()
        {
            self.state().erased[(entity.index())]
                .as_mut()
                .unwrap()
                .push(_handle.into());
            erased.copy_to((self.row_column(&entity, i)), meta);
        }
        (&entity);
        Some(entity)
    }

    pub fn free(&self, entities: impl IntoIterator<Item = Entity>) {
        for entity in entities {
            self.coalese_row(&entity);
            self.state().erased[entity.index()] = None;
            self.state().freed.push(entity.incr_gen());
        }
    }

    pub fn entity_head(&self) -> *mut u8 {
        unsafe { self.head.add(mem::size_of::<Archetype>()) }
    }

    pub fn coalese_row(&self, entity: &Entity) {
        let idx = entity.index();
        for (i, meta) in self.archetype().iter().enumerate() {
            let Some(erased) = &mut self.state().erased[idx] else {
                unreachable!();
            };
            let mut data = Data {
                ptr: self.row_column(entity, i),
                meta: *meta,
            };
            data.copy_from(todo!(), meta);
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
    fn init(entity_head: *mut u8, capacity: usize, row_size: usize) -> Self {
        let freed = (0..capacity)
            .map(|i| unsafe { entity_head.add(i * row_size) })
            .map(Entity::new)
            .rev()
            .collect::<Vec<_>>();
        let erased = iter::repeat_with(|| None).take(capacity).collect();
        Self { freed, erased }
    }
}
