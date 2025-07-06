use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::time::{Duration, Instant};
use std::sync::{Arc, Mutex};

/// Error returned when a future times out
#[derive(Debug, Clone, Copy)]
pub struct TimeoutError;

impl std::fmt::Display for TimeoutError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "operation timed out")
    }
}

impl std::error::Error for TimeoutError {}

/// A future that times out after a specified duration
pub struct Timeout<F> {
    future: F,
    deadline: Instant,
    completed: Arc<Mutex<bool>>,
}

impl<F> Timeout<F> {
    fn new(future: F, duration: Duration) -> Self {
        Self {
            future,
            deadline: Instant::now() + duration,
            completed: Arc::new(Mutex::new(false)),
        }
    }
}

impl<F: Future> Future for Timeout<F> {
    type Output = Result<F::Output, TimeoutError>;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // Check if we've timed out
        if Instant::now() >= self.deadline {
            return Poll::Ready(Err(TimeoutError));
        }

        // Get a pinned reference to the inner future
        let this = unsafe { self.get_unchecked_mut() };
        let future = unsafe { Pin::new_unchecked(&mut this.future) };

        // Poll the inner future
        match future.poll(cx) {
            Poll::Ready(output) => {
                *this.completed.lock().unwrap() = true;
                Poll::Ready(Ok(output))
            }
            Poll::Pending => {
                // Set up a timer to wake us when the deadline is reached
                let waker = cx.waker().clone();
                let deadline = this.deadline;
                let completed = this.completed.clone();
                
                std::thread::spawn(move || {
                    let now = Instant::now();
                    if now < deadline {
                        std::thread::sleep(deadline - now);
                    }
                    
                    // Only wake if not completed
                    if !*completed.lock().unwrap() {
                        waker.wake();
                    }
                });
                
                Poll::Pending
            }
        }
    }
}

/// Applies a timeout to a future
pub fn timeout<F: Future>(duration: Duration, future: F) -> Timeout<F> {
    Timeout::new(future, duration)
}

/// Helper to make async blocks work with timeout
pub async fn timeout_async<F, T>(duration: Duration, f: F) -> Result<T, TimeoutError>
where
    F: Future<Output = T>,
{
    timeout(duration, f).await
}