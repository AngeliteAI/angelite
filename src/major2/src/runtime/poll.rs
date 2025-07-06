use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, Wake, Waker};
use std::sync::Arc;

/// A handle to poll a future without blocking
pub struct PollHandle<T> {
    future: Pin<Box<dyn Future<Output = T>>>,
    waker: Arc<NoopWaker>,
}

impl<T> PollHandle<T> {
    pub fn new<F>(future: F) -> Self
    where
        F: Future<Output = T> + 'static,
    {
        Self {
            future: Box::pin(future),
            waker: Arc::new(NoopWaker),
        }
    }

    /// Poll the future once. Returns Some(result) if ready, None if pending.
    pub fn poll_ready(&mut self) -> Option<T> {
        let waker = self.waker.clone().into();
        let mut cx = Context::from_waker(&waker);
        
        match self.future.as_mut().poll(&mut cx) {
            Poll::Ready(value) => Some(value),
            Poll::Pending => None,
        }
    }
}

/// A handle to poll a Send future without blocking
pub struct SendPollHandle<T> {
    future: Pin<Box<dyn Future<Output = T> + Send>>,
    waker: Arc<NoopWaker>,
}

impl<T> SendPollHandle<T> {
    pub fn new<F>(future: F) -> Self
    where
        F: Future<Output = T> + Send + 'static,
    {
        Self {
            future: Box::pin(future),
            waker: Arc::new(NoopWaker),
        }
    }

    /// Poll the future once. Returns Some(result) if ready, None if pending.
    pub fn poll_ready(&mut self) -> Option<T> {
        let waker = self.waker.clone().into();
        let mut cx = Context::from_waker(&waker);
        
        match self.future.as_mut().poll(&mut cx) {
            Poll::Ready(value) => Some(value),
            Poll::Pending => None,
        }
    }
}

/// A no-op waker that does nothing when woken
struct NoopWaker;

impl Wake for NoopWaker {
    fn wake(self: Arc<Self>) {
        // Do nothing - we'll poll manually
    }
    
    fn wake_by_ref(self: &Arc<Self>) {
        // Do nothing - we'll poll manually
    }
}

/// Helper to create a pollable handle for any future
pub fn pollable<F, T>(future: F) -> PollHandle<T>
where
    F: Future<Output = T> + 'static,
{
    PollHandle::new(future)
}

/// Helper to create a pollable handle for a Send future
pub fn pollable_send<F, T>(future: F) -> SendPollHandle<T>
where
    F: Future<Output = T> + Send + 'static,
{
    SendPollHandle::new(future)
}