use crate::system::func::Cmd;
use base::rt::Handle;
use flume::Receiver;
use func::{Finished, Return};
use std::pin::Pin;

pub mod func;
pub mod graph;
pub mod param;
pub mod sequence;

pub type System = Pin<Box<dyn Fn(Receiver<Cmd>) -> Handle<Result<Return, Finished>>>>;
