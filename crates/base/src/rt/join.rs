use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
};

use crate::collections::array::Array;
use pin_project::pin_project;

#[pin_project]
pub struct UnorderedJoin<T, const N: usize> {
    #[pin]
    futures: Array<Option<Pin<Box<dyn Future<Output = T> + Send>>>, N>,
    results: Array<Option<T>, N>,
    remaining: usize,
}

impl<T: Send + 'static, const N: usize> UnorderedJoin<T, N> {
    pub fn new() -> Self {
        Self {
            futures: Array::new(),
            results: Array::new(),
            remaining: 0,
        }
    }

    pub fn push(&mut self, future: impl Future<Output = T> + Send + 'static) {
        self.futures.push(Some(Box::pin(future)));
        self.results.push(None);
        self.remaining += 1;
    }
}

impl<T: Send + 'static, const N: usize> Future for UnorderedJoin<T, N> {
    type Output = Array<T, N>;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let this = self.project();
        let mut futures = this.futures;
        let results = this.results;
        let remaining = this.remaining;

        // Try polling each pending future
        for i in 0..futures.len() {
            if let Some(mut future) = futures[i].take() {
                match future.as_mut().poll(cx) {
                    Poll::Ready(result) => {
                        results[i] = Some(result);
                        *remaining -= 1;
                    }
                    Poll::Pending => {
                        futures[i] = Some(future);
                    }
                }
            }
        }

        // Return when all futures complete
        if *remaining == 0 {
            let mut output = Array::new();
            for i in 0..results.len() {
                output.push(results[i].take().unwrap());
            }
            Poll::Ready(output)
        } else {
            Poll::Pending
        }
    }
}
