use std::{
    pin::{Pin, pin},
    task::{Context, Poll},
};

use pin_project::pin_project;

use crate::time::{Duration, Millis};

use super::backoff::Backoff;

// Async primitive that retries operations
#[pin_project]
pub(crate) struct Retry<T, F> {
    f: F,
    #[pin]
    backoff: Backoff,
    state: RetryState<T>,
}

enum RetryState<T> {
    Ready,
    Waiting,
    Done(T),
}

impl<T, F, E> Retry<T, F>
where
    F: FnMut() -> Result<T, E>,
{
    pub fn new(f: F) -> Self {
        Self {
            f,
            backoff: Backoff::with_step(Duration::<Millis>::from(1)),
            state: RetryState::Ready,
        }
    }
}

impl<T, F, E> Future for Retry<T, F>
where
    F: FnMut() -> Result<T, E>,
{
    type Output = T;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let mut this = self.project();
        loop {
            match &mut this.state {
                RetryState::Ready => {
                    match (this.f)() {
                        Ok(value) => {
                            *this.state = RetryState::Done(value);
                            continue;
                        }
                        Err(_) => {
                            // Start backoff
                            *this.state = RetryState::Waiting;
                            let backoff = this.backoff.wait();
                            let backoff = pin!(backoff);
                            match backoff.poll(cx) {
                                Poll::Ready(()) => {
                                    *this.state = RetryState::Ready;
                                    continue;
                                }
                                Poll::Pending => return Poll::Pending,
                            }
                        }
                    }
                }
                RetryState::Waiting => {
                    // Continue backoff
                    let backoff = this.backoff.wait();
                    let backoff = pin!(backoff);
                    match backoff.poll(cx) {
                        Poll::Ready(()) => {
                            *this.state = RetryState::Ready;
                            continue;
                        }
                        Poll::Pending => return Poll::Pending,
                    }
                }
                RetryState::Done(value) => {
                    return Poll::Ready(std::mem::replace(
                        value,
                        // This is safe because we immediately return
                        unsafe { std::mem::MaybeUninit::uninit().assume_init() },
                    ));
                }
            }
        }
    }
}
