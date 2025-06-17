use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
};

pub struct UnorderedJoin<T> {
    futures: Vec<Option<Pin<Box<dyn Future<Output = T> + Send>>>>,
    len: usize,
}

impl<T: Send + 'static> UnorderedJoin<T> {
    pub fn new() -> Self {
        Self {
            futures: Vec::new(),
            len: 0,
        }
    }

    pub fn push(&mut self, future: impl Future<Output = T> + Send + 'static) {
        self.futures.push(Some(Box::pin(future)));
        self.len += 1;
    }
}

impl<T: Send + 'static> Future for UnorderedJoin<T> {
    type Output = Vec<T>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let mut completed = Vec::new();
        let mut remaining = self.len;

        // Poll remaining futures
        for i in 0..self.futures.len() {
            if let Some(fut) = self.futures[i].as_mut() {
                match fut.as_mut().poll(cx) {
                    Poll::Ready(val) => {
                        completed.push(val);
                        self.futures[i] = None;
                        remaining -= 1;
                    }
                    Poll::Pending => {}
                }
            }
        }

        if remaining == 0 {
            Poll::Ready(completed)
        } else {
            Poll::Pending
        }
    }
}
