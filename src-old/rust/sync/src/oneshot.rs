use std::{
    cell::UnsafeCell,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    task::Waker,
};

#[derive(Debug)]
pub struct Oneshot<T: Send>(Arc<Inner<T>>);

impl<T: Send> Clone for Oneshot<T> {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}
unsafe impl<T: Send> Send for Inner<T> {}
unsafe impl<T: Send> Sync for Inner<T> {}

#[derive(Debug)]
pub struct Inner<T> {
    value: UnsafeCell<Option<T>>,
    is_sent: AtomicBool,
    waker: UnsafeCell<Option<Waker>>,
}

impl<T: Send> Default for Oneshot<T> {
    fn default() -> Self {
        Self(Arc::new(Inner {
            value: UnsafeCell::new(None),
            is_sent: AtomicBool::new(false),
            waker: UnsafeCell::new(None),
        }))
    }
}

impl<T: Send> Oneshot<T> {
    pub fn send(self, value: T) -> Result<(), T> {
        let inner = self.0;
        if inner.is_sent.swap(true, Ordering::AcqRel) {
            return Err(value);
        }
        unsafe {
            *inner.value.get() = Some(value);
        }
        let waker = unsafe { &*inner.waker.get() };
        if let Some(waker) = waker {
            waker.wake_by_ref();
        }
        Ok(())
    }
    pub fn recv(self) -> Recv<T> {
        Recv { inner: self.0 }
    }
}

pub struct Recv<T: Send> {
    inner: Arc<Inner<T>>,
}

impl<T: Send> Future for Recv<T> {
    type Output = T;

    fn poll(
        self: std::pin::Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        let inner = &*self.inner;
        if inner.is_sent.load(Ordering::Acquire) {
            let value = unsafe { inner.value.get().as_mut().unwrap() };
            let value = value.take().unwrap();
            return std::task::Poll::Ready(value);
        }
        unsafe {
            *inner.waker.get() = Some(cx.waker().clone());
        }
        std::task::Poll::Pending
    }
}
