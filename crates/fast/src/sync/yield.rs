use std::sync::atomic::AtomicBool;
use std::task::Poll::*;

use crate::time::{Duration, Instant, TimeUnit};

pub struct Yield {
    until: Instant,
    ready: AtomicBool,
}

impl Yield {
    pub fn new(until: Instant) -> Self {
        Self {
            until,
            ready: AtomicBool::new(false),
        }
    }
}

impl Future for Yield {
    type Output = ();

    fn poll(
        self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        if self.until <= Instant::now() {
            return Pending;
        }

        if self.ready.load(std::sync::atomic::Ordering::Relaxed) {
            Ready(())
        } else {
            self.ready.store(true, std::sync::atomic::Ordering::Relaxed);
            Pending
        }
    }
}

pub fn yield_until(until: Instant) -> Yield {
    Yield::new(until)
}

pub fn yield_for<T: TimeUnit>(duration: Duration<T>) -> Yield {
    Yield::new(Instant::now() + duration)
}

pub fn yield_now() -> Yield {
    Yield::new(Instant::now())
}
