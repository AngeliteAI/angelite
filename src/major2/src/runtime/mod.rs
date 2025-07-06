//! Custom thread-based async runtime for the major engine
//! This provides a lightweight alternative to tokio for internal async operations

use std::future::Future;

pub mod executor;
pub mod task;
pub mod rwlock;
pub mod channel;
pub mod timeout;
pub mod poll;
#[cfg(test)]
mod test;

pub use executor::{Executor, Handle};
pub use task::{Task, TaskId, JoinHandle};
pub use rwlock::{RwLock, RwLockReadGuard, RwLockWriteGuard};
pub use channel::{async_channel, AsyncSender, AsyncReceiver};
pub use timeout::{timeout, timeout_async, TimeoutError};
pub use poll::{pollable, pollable_send, PollHandle, SendPollHandle};

/// Create a new runtime with the specified number of worker threads
pub fn runtime(num_threads: usize) -> Executor {
    Executor::new(num_threads)
}

/// Block on a future using a minimal single-threaded executor
pub fn block_on<F: Future>(future: F) -> F::Output {
    executor::block_on(future)
}

/// Spawn a future on the current runtime
pub fn spawn<F>(future: F) -> JoinHandle<F::Output>
where
    F: Future + Send + 'static,
    F::Output: Send + 'static,
{
    Handle::current().spawn(future)
}

/// Spawn a blocking task on a dedicated thread
pub fn spawn_blocking<F, R>(f: F) -> JoinHandle<R>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    Handle::current().spawn_blocking(f)
}

/// Try to spawn a future on the current runtime, returning None if no runtime is set
pub fn try_spawn<F>(future: F) -> Option<JoinHandle<F::Output>>
where
    F: Future + Send + 'static,
    F::Output: Send + 'static,
{
    Handle::try_current().map(|h| h.spawn(future))
}