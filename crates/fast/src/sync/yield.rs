use std::pin::pin;
use std::sync::atomic::AtomicBool;
use std::task::Poll::*;

use crate::{
    rt::block_on,
    time::{Duration, Instant, TimeUnit, wait_until},
};
use crate::rt::{poll, waker};
use crate::rt::worker::current_worker;

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
        let waker = cx.waker().clone();
        poll(cx, async move {
            if self.until > Instant::now() {
                let waker = waker.clone();
                wait_until(self.until, move || {
                    dbg!("WOAHHHHHH");
                    waker.wake_by_ref();
                }).await;
            }

            loop {
                if self.ready.load(std::sync::atomic::Ordering::Relaxed) {
                    return;
                } else {
                    self.ready.store(true, std::sync::atomic::Ordering::Relaxed);
                }
            }
        })

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
