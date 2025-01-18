use std::{
    rc::Weak,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering::*},
    },
};

use crate::collections::skip::List;

pub struct Ordered<T>(usize, T);

impl<T> Ordered<T> {
    fn order(order: usize, value: T) -> Self {
        Self(order, value)
    }
}

impl<T> PartialEq for Ordered<T> {
    fn eq(&self, other: &Self) -> bool {
        self.0 == other.0
    }
}

impl<T> PartialOrd for Ordered<T> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        self.0.partial_cmp(&other.0)
    }
}

pub struct Queue<T> {
    count: Arc<AtomicUsize>,
    list: List<Ordered<T>>,
}

impl<T> Default for Queue<T> {
    fn default() -> Self {
        Self {
            count: Arc::new(AtomicUsize::new(0)),
            list: List::new(),
        }
    }
}

impl<T> Queue<T> {
    pub async fn enqueue(&self, value: T) {
        self.list
            .insert(Ordered(self.count.fetch_add(1, Relaxed), value)).await;
    }

    pub fn dequeue(&self) -> Option<T> {
        self.list.remove_first().map(|Ordered(_, value)| value)
    }

    pub fn is_empty(&self) -> bool {
        self.list.is_empty()
    }
}
