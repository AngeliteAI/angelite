use std::pin::Pin;

use fast::rt::Handle;
use func::Return;

pub mod func;
pub mod graph;
pub mod sequence;

pub type System = Pin<Box<dyn Fn() -> Handle<Return>>>;
