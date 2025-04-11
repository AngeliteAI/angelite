//! Context related functions and types

use libc::{size_t, c_void};
use crate::types::{Context, Complete, Error};

unsafe extern "C" {
    pub fn current() -> *mut Context;
    pub fn init(desired_concurrency: usize) -> *mut Context;
    pub fn shutdown() -> ();
    pub fn submit() -> usize;
    pub fn poll(completions: *mut Complete, max_completions: usize) -> usize;
    pub fn last_error() -> *mut Error;
}