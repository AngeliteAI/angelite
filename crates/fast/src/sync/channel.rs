pub struct Channel<T: Send, const Buf: usize>(Arc<Inner<T, Buf>>);

unsafe impl<T, const Buf: usize> Send for Channel<T, Buf> where T: Send {}
unsafe impl<T, const Buf: usize> Sync for Channel<T, Buf> where T: Send {}

impl<T: Send, const Buf: usize> Clone for Channel<T, Buf> {
    fn clone(&self) -> Self {
        Self(self.0.clone())
    }
}

struct Inner<T, const N: usize> {
    buffer: [UnsafeCell<Option<T>>; N],
    wakers: UnsafeCell<Vec<Waker>>,
    waker_active: AtomicUsize,
    head: AtomicUsize,
    tail: AtomicUsize,
    closed: AtomicBool,
}

#[derive(PartialEq, Eq, Clone, Copy)]
enum Direction {
    Head,
    Tail,
}
use std::{
    cell::UnsafeCell,
    iter,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
    task::{self, Poll, Waker},
};

use Direction::*;

impl<T: Send, const N: usize> Channel<T, N> {
    pub fn send(&self, value: T) -> Sender<'_, T, N> {
        Sender {
            value: Some(value).into(),
            channel: self,
        }
    }

    pub fn recv(&self) -> Receiver<'_, T, N> {
        Receiver { channel: self }
    }

    pub fn close(&self) {
        self.0.closed.store(true, Ordering::Release);
        let wakers = unsafe { self.0.wakers.get().as_mut().unwrap() };
        wakers.drain(..).for_each(Waker::wake);
    }

    pub fn is_closed(&self) -> bool {
        self.0.closed.load(Ordering::Acquire)
    }

    pub fn len(&self) -> usize {
        self.0
            .head
            .load(Ordering::Acquire)
            .saturating_sub(self.0.tail.load(Ordering::Acquire));
        let head = self.0.head.load(Ordering::Acquire);
        let tail = self.0.tail.load(Ordering::Acquire);
        if head >= tail {
            head - tail
        } else {
            N - (tail - head)
        }
    }

    pub fn capacity(&self) -> usize {
        N
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn is_full(&self) -> bool {
        self.len() == N
    }

    pub fn next(&self, direction: Direction) -> Result<(usize, usize), ()> {
        let head = self.0.head.load(Ordering::Acquire);
        let tail = self.0.tail.load(Ordering::Acquire);
        let (current, other) = match direction {
            Direction::Head => (head, tail),
            Direction::Tail => (tail, head),
        };
        let next = (current + 1) % N;

        if direction == Head && next == tail {
            if self.is_full() {
                return Err(());
            }
        } else if direction == Tail && head == tail {
            return Err(());
        }
        Ok((current, next))
    }

    pub fn is_idle(&self) -> bool {
        self.0.waker_active.load(Ordering::Acquire) == 0
    }

    pub fn try_send(&self, value: T) -> Option<Result<(), T>> {
        match self.poll_send(value) {
            Poll::Ready(x) => Some(x),
            Poll::Pending => None,
        }
    }

    pub fn try_recv(&self) -> Option<Result<T, ()>> {
        match self.poll_recv() {
            Poll::Ready(x) => Some(x.ok_or(())),
            Poll::Pending => None,
        }
    }

    pub fn poll_send(&self, value: T) -> Poll<Result<(), T>> {
        if self.is_full() {
            return Poll::Ready(Err(value));
        }
        self.attempt(Direction::Head, value, |slot, value| unsafe {
            *slot.get().as_mut().unwrap() = Some(value);
        })
    }

    pub fn attempt<U, R>(
        &self,
        direction: Direction,
        value: U,
        action: impl FnOnce(&UnsafeCell<Option<T>>, U) -> R,
    ) -> Poll<Result<R, U>> {
        let Self(inner) = self;
        let Inner { buffer, .. } = &**inner;
        if self.is_closed() {
            dbg!("1");
            return Poll::Ready(Err(value));
        }
        let Ok((current, next)) = self.next(direction) else {
            return Poll::Pending;
        };

        let cas = match direction {
            Direction::Head => &inner.head,
            Direction::Tail => &inner.tail,
        };

        match cas.compare_exchange(current, next, Ordering::Release, Ordering::Relaxed) {
            Ok(_) => {
                let slot = &buffer[current];
                let ret = (action)(slot, value);
                self.wake();
                Poll::Ready(Ok(ret))
            }
            Err(_) => Poll::Pending,
        }
    }

    pub fn poll_recv(&self) -> Poll<Option<T>> {
        if self.is_empty() {
            return Poll::Pending;
        }
        let action =
            |slot: &UnsafeCell<Option<T>>, _| unsafe { slot.get().as_mut().unwrap().take() };

        match self.attempt(Tail, (), action) {
            Poll::Ready(Ok(Some(x))) => Poll::Ready(Some(x)),
            Poll::Ready(Err(x)) => Poll::Ready(None),
            Poll::Ready(Ok(None)) => Poll::Pending,
            Poll::Pending => Poll::Pending,
        }
    }

    fn wake(&self) {
        let Self(inner) = self;
        let Inner {
            buffer,
            wakers,
            waker_active,
            head,
            tail,
            closed,
        } = &**inner;
        let wakers = unsafe { wakers.get().as_mut().unwrap() };
        let waker_count = waker_active.load(Ordering::Acquire);

        if waker_count == 0 {
            return;
        }

        let head = head.load(Ordering::Acquire);
        let tail = tail.load(Ordering::Acquire);

        if head == tail {
            return;
        }

        if let Some(waker) = wakers.pop() {
            waker.wake();
            waker_active.fetch_sub(1, Ordering::Release);
        }
    }

    fn sleep(&self, cx: &mut task::Context<'_>) {
        let Self(inner) = self;
        let Inner {
            buffer,
            wakers,
            waker_active,
            head,
            tail,
            closed,
        } = &**inner;

        let wakers = unsafe { wakers.get().as_mut().unwrap() };
        let waker_active = waker_active.load(Ordering::Acquire);

        if self.is_idle() {
            return;
        }

        let head = head.load(Ordering::Acquire);
        let tail = tail.load(Ordering::Acquire);

        if head == tail {
            return;
        }

        wakers.push(cx.waker().clone());
    }
}

impl<T: Send, const N: usize> Default for Channel<T, N> {
    fn default() -> Self {
        let buffer = iter::repeat_with(|| None.into())
            .take(N)
            .collect::<Vec<_>>()
            .try_into()
            .unwrap();
        Self(Arc::new(Inner {
            buffer,
            wakers: Default::default(),
            waker_active: 0.into(),
            head: 0.into(),
            tail: 0.into(),
            closed: false.into(),
        }))
    }
}

pub struct Sender<'a, T: Send, const N: usize> {
    channel: &'a Channel<T, N>,
    value: UnsafeCell<Option<T>>,
}

impl<'a, T: Send, const N: usize> Future for Sender<'a, T, N> {
    type Output = Result<(), T>;

    fn poll(self: std::pin::Pin<&mut Self>, cx: &mut task::Context<'_>) -> Poll<Self::Output> {
        let Self { channel, value } = &*self;

        match channel.poll_send(unsafe { value.get().as_mut().unwrap().take().unwrap() }) {
            Poll::Ready(Ok(x)) => Poll::Ready(Ok(x)),
            Poll::Ready(Err(x)) => {
                unsafe {
                    value.get().as_mut().unwrap().replace(x);
                }
                Poll::Pending
            }
            Poll::Pending => {
                channel.sleep(cx);
                Poll::Pending
            }
        }
    }
}

pub struct Receiver<'a, T: Send, const N: usize> {
    channel: &'a Channel<T, N>,
}

impl<'a, T: Send, const N: usize> Future for Receiver<'a, T, N> {
    type Output = Result<T, ()>;

    fn poll(self: std::pin::Pin<&mut Self>, cx: &mut task::Context<'_>) -> Poll<Self::Output> {
        match self.channel.poll_recv() {
            Poll::Ready(Some(x)) => Poll::Ready(Ok(x)),
            Poll::Ready(None) => Poll::Ready(Err(())),
            Poll::Pending => {
                self.channel.sleep(cx);
                Poll::Pending
            }
        }
    }
}
