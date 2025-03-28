#![feature(unboxed_closures, async_fn_traits, negative_impls)]
#[cfg(feature = "system")]
pub mod backoff;
#[cfg(feature = "system")]
pub mod barrier;
pub mod mutex;
pub mod oneshot;
#[cfg(feature = "system")]
pub mod retry;
#[cfg(feature = "system")]
pub mod split;
#[cfg(feature = "system")]
pub mod r#yield;

pub fn poll(
    cx: &mut std::task::Context<'_>,
    fut: impl IntoFuture<Output = ()>,
) -> std::task::Poll<()> {
    let fut = fut.into_future();
    pin!(fut).poll(cx)
}
