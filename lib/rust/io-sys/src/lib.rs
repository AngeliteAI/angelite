//! Raw FFI bindings to the example C library.
//!
//! This crate provides raw FFI bindings to the example C library,
//! exposing the C API through a Rust interface.

pub use libc;

pub mod types;
pub mod constants;
pub mod error;
pub mod io;
pub mod cpu;
pub mod context;
pub mod file;
pub mod socket;
