use std::{
    cell::UnsafeCell,
    sync::{Arc, OnceLock},
    thread::{self, Thread},
};

use crate::collections::skip::Map;

#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq, PartialOrd, Ord, Default)]
pub struct ThreadId(usize);

impl ThreadId {
    fn current() -> Self {
        Self::from(&thread::current())
    }
}

impl<'a> From<&'a Thread> for ThreadId {
    fn from(value: &'a Thread) -> Self {
        Self(value.id().as_u64().get() as _)
    }
}

pub struct Local<T: Sync> {
    values: OnceLock<Arc<Map<ThreadId, UnsafeCell<T>>>>,
}

impl<T: Sync> !Send for Local<T> {}

impl<T: Sync> Default for Local<T> {
    fn default() -> Self {
        Self {
            values: Default::default(),
        }
    }
}
impl<T: Sync> Local<T> {
    pub const fn new() -> Self {
        Self {
            values: OnceLock::new(),
        }
    }

    pub fn init_shared_map() -> Arc<Map<ThreadId, UnsafeCell<T>>> {
        Arc::new(Map::default())
    }

    pub fn all_values(&self) -> impl Iterator<Item = &T> {
        let values = self.values.get_or_init(Self::init_shared_map);
        values
            .iter()
            .map(|(_, cell)| unsafe { cell.get().as_ref().unwrap() })
    }

    // Initialize value for a specific thread
    pub async fn init_for_thread(&self, thread: &Thread, value: T) -> Option<T> {
        let id = ThreadId::from(thread);
        let values = self.values.get_or_init(Self::init_shared_map);
        let t = values
            .insert(id, UnsafeCell::new(value))
            .await
            .map(|cell| unsafe { cell.into_inner() });
        dbg!("yo3");
        t
    }

    pub async fn get_or_init(&self, init: impl FnOnce() -> T) -> &T {
        let id = ThreadId::current();
        let values = self.values.get_or_init(Self::init_shared_map);

        if !values.contains_key(&id).await {
            values.insert(id, UnsafeCell::new(init())).await;
        }

        unsafe { &*values.get(&id).await.expect("Value must exist").get() }
    }

    pub async fn get_mut(&self) -> Option<&mut T> {
        let id = ThreadId::current();
        let values = self.values.get_or_init(Self::init_shared_map);

        unsafe { values.get(&id).await.map(|cell| &mut *cell.get()) }
    }

    pub async fn take(&self) -> Option<T> {
        let id = ThreadId::current();
        let values = self.values.get_or_init(Self::init_shared_map);
        values
            .remove(&id)
            .await
            .map(|cell| unsafe { cell.into_inner() })
    }
    pub fn len(&self) -> usize {
        self.values.get_or_init(Self::init_shared_map).len()
    }
}
