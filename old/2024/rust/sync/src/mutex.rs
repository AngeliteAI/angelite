use std::{
    borrow::BorrowMut,
    cell::UnsafeCell,
    iter,
    pin::{Pin, pin},
    sync::atomic::{AtomicBool, AtomicUsize, Ordering},
    task::{self, Poll, Waker},
};

#[derive(Default)]
pub struct Mutex<T, const N: usize = 128> {
    locked: AtomicBool,
    queue: Queue<N>,
    data: UnsafeCell<T>,
}

impl<T, const N: usize> Mutex<T, N> {
    pub fn new(data: T) -> Self {
        Self {
            locked: AtomicBool::new(false),
            queue: Queue::default(),
            data: UnsafeCell::new(data),
        }
    }

    pub fn lock(&self) -> Lock<'_, T, N> {
        Lock {
            mutex: self,
            push: None,
        }
    }
}

pub struct Lock<'a, T, const N: usize> {
    mutex: &'a Mutex<T, N>,
    push: Option<Pin<Box<Push<'a, N>>>>,
}

impl<'a, T, const N: usize> Future for Lock<'a, T, N> {
    type Output = Guard<'a, T, N>;

    fn poll(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut task::Context<'_>,
    ) -> task::Poll<Self::Output> {
        loop {
            if self.mutex.locked.load(Ordering::Acquire) {
                break if let Some(push) = &mut self.push {
                    let push = pin!(push);
                    push.poll(cx).map(|_| Guard { mutex: self.mutex })
                } else {
                    self.push = Some(Box::pin(self.mutex.queue.push(cx.waker().clone())));
                    Poll::Pending
                };
            } else if self
                .mutex
                .locked
                .compare_exchange(false, true, Ordering::Acquire, Ordering::Relaxed)
                .is_ok()
            {
                break Poll::Ready(Guard { mutex: self.mutex });
            }
        }
    }
}

pub struct Guard<'a, T, const N: usize> {
    mutex: &'a Mutex<T, N>,
}

pub struct Queue<const N: usize> {
    head: AtomicUsize,
    tail: AtomicUsize,
    data: [UnsafeCell<Option<Waker>>; N],
}

impl<const N: usize> Default for Queue<N> {
    fn default() -> Self {
        let data = iter::repeat_with(|| None.into())
            .take(N)
            .collect::<Vec<_>>()
            .try_into()
            .unwrap();
        Self {
            head: 0.into(),
            tail: 0.into(),
            data,
        }
    }
}

impl<const N: usize> Queue<N> {
    fn push(&self, waker: task::Waker) -> Push<N> {
        Push {
            waker: waker.into(),
            queue: self,
        }
    }

    fn pop(&self) -> Pop<N> {
        Pop { queue: self }
    }
}

pub struct Push<'a, const N: usize> {
    waker: Option<task::Waker>,
    queue: &'a Queue<N>,
}

impl<'a, const N: usize> Future for Push<'a, N> {
    type Output = ();

    fn poll(
        mut self: std::pin::Pin<&mut Self>,
        cx: &mut task::Context<'_>,
    ) -> task::Poll<Self::Output> {
        let queue = &mut self.queue;
        let tail = queue.tail.load(Ordering::Acquire);
        let next_tail = (tail + 1) % N;

        assert_ne!(next_tail, queue.head.load(Ordering::Acquire));

        match queue
            .tail
            .compare_exchange(tail, next_tail, Ordering::Release, Ordering::Acquire)
        {
            Ok(_) => {
                let slot = &queue.data[tail];
                unsafe {
                    *slot.get().as_mut().unwrap() = self.waker.take();
                }
                Poll::Ready(())
            }
            Err(_) => Poll::Pending,
        }
    }
}

pub struct Pop<'a, const N: usize> {
    queue: &'a Queue<N>,
}

impl<'a, const N: usize> Future for Pop<'a, N> {
    type Output = ();

    fn poll(mut self: Pin<&mut Self>, cx: &mut task::Context<'_>) -> Poll<Self::Output> {
        let queue = &mut self.queue;
        let head = queue.head.load(Ordering::Acquire);
        let next_head = (head + 1) % N;
        if let Ok(_) =
            queue
                .head
                .compare_exchange(head, next_head, Ordering::Release, Ordering::Acquire)
        {
            let slot = &queue.data[head];
            if let Some(waker) = unsafe { slot.get().as_mut().unwrap().take() } {
                waker.wake();
            }
            Poll::Ready(())
        } else {
            Poll::Pending
        }
    }
}
