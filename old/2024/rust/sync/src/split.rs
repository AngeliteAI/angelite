use std::{
    cell::UnsafeCell,
    sync::{Arc, atomic::AtomicPtr},
};

use crate::collections::skip::List;

pub struct Split<T, O>(Inner<T, O>);

pub type Epoch = usize;
pub type Key = usize;

pub struct Inner<T, O> {
    read: AtomicPtr<T>,
    write: AtomicPtr<T>,
    log: List<O>,
}

pub trait Apply<O> {
    fn apply_first(&mut self, operation: &mut O);
    fn apply_second(&mut self, operation: O);
}
