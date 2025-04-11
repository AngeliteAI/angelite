#![feature(set_ptr_value, trait_upcasting, ptr_metadata)]
pub mod server;
pub use server::{Router, serve};
