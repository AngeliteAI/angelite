use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering::*},
};

use crate::{
    rng::{Exponential, Random, Temporal, rng},
    rt::poll,
    time::{Convert, Duration, Instant, Millis, Nanos, Seconds},
};

use super::r#yield::yield_until;

#[derive(Clone)]
pub struct Backoff {
    count: Arc<AtomicUsize>,
    step: Duration<Millis>,
    spread: Duration<Millis>,
}

impl Backoff {
    pub fn with_step_spread(step: Duration<Millis>, spread: Duration<Millis>) -> Self {
        Self {
            count: Arc::new(AtomicUsize::new(1)),
            step,
            spread,
        }
    }
    pub fn with_step(step: Duration<Millis>) -> Self {
        let spread = step * 0.1;
        Self::with_step_spread(step, spread)
    }
    pub fn wait(&self) -> Wait {
        Wait {
            count: self.count.clone(),
            start: Instant::now(),
            step: self.step,
            spread: self.spread,
        }
    }
}

impl AsyncFnOnce<()> for Backoff {
    type CallOnceFuture = <Self as AsyncFnMut<()>>::CallRefFuture<'static>;
    type Output = ();
    extern "rust-call" fn async_call_once(self, args: ()) -> Self::CallOnceFuture {
        self.async_call(args)
    }
}

impl AsyncFnMut<()> for Backoff {
    type CallRefFuture<'a> = Wait;
    extern "rust-call" fn async_call_mut(&mut self, args: ()) -> Self::CallRefFuture<'_> {
        self.async_call(args)
    }
}

impl AsyncFn<()> for Backoff {
    extern "rust-call" fn async_call(&self, args: ()) -> Self::CallRefFuture<'_> {
        let Self {
            count,
            step,
            spread,
        } = self.clone();
        Wait {
            count,
            start: Instant::now(),
            step,
            spread,
        }
    }
}

pub struct Wait {
    count: Arc<AtomicUsize>,
    start: Instant,
    step: Duration<Millis>,
    spread: Duration<Millis>,
}

impl Future for Wait {
    type Output = ();

    fn poll(
        self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        let start = self.start;
        let step = self.step;
        let count = self.count.fetch_add(1, Relaxed);
        poll(cx, async move {
            let spread = rng()
                .await
                .map(|x| {
                    dbg!(x.sample::<Duration<Millis>>(&Temporal::new(
                        Exponential::new(dbg!(self.spread.get().into_inner() as f64 + 1.)),
                        10.0,
                    )))
                })
                .unwrap_or(Duration::INSTANT.into::<Millis>());
            yield_until(start + step * count + spread).await;
        })
    }
}
