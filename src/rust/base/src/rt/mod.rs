use std::{
    async_iter::AsyncIterator,
    cell::{OnceCell, UnsafeCell},
    marker::PhantomData,
    mem::{self, ManuallyDrop},
    ops::{self},
    pin::{Pin, pin},
    sync::{
        Arc, OnceLock,
        atomic::{
            AtomicBool, AtomicPtr, AtomicU8, AtomicUsize,
            Ordering::{self, *},
        },
    },
    task::{
        Context,
        Poll::{self, *},
        RawWaker, RawWakerVTable, Wake, Waker,
    },
};

use derive_more::derive::{Deref, DerefMut, From};
use flume::{Receiver, r#async::RecvFut, unbounded};
use pin_project::pin_project;
use worker::{WorkerHandle, current_worker, select_worker};

use crate::sync::backoff::Wait;
use crate::{
    collections::queue::Queue,
    prelude::Vector,
    sync::{barrier::Barrier, split::Split},
};

pub mod join;
pub mod worker;

#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Local;
#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Remote;

pub trait Kind: Copy {
    type Call;
    type Fut;
    type Coro;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized;
    async fn schedule(task: Task<Self>);
}

impl Kind for Local {
    type Call = Box<dyn FnOnce()>;
    type Fut = Pin<Box<dyn Future<Output = ()>>>;
    type Coro = Pin<Box<dyn AsyncIterator<Item = ()>>>;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized,
    {
        // Create notify handle
        let notify = Arc::new(Notify::new(id));

        Waker::from(Arc::new(NotifyWaker(notify)))
    }

    async fn schedule(task: Task<Self>) {
        current_worker().await.unwrap().local.enqueue(task).await;
    }
}

impl Kind for Remote {
    type Call = Box<dyn FnOnce() + Send>;
    type Fut = Pin<Box<dyn Future<Output = ()> + Send>>;
    type Coro = Pin<Box<dyn AsyncIterator<Item = ()> + Send>>;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized,
    {
        // Create notify handle
        let notify = Arc::new(Notify::new(id));

        Waker::from(Arc::new(NotifyWaker(notify)))
    }

    async fn schedule(task: Task<Self>) {
        current_worker().await.unwrap().remote.enqueue(task).await;
    }
}

struct NotifyWaker<K: Kind>(Arc<Notify<K>>);

impl<K: Kind> Wake for NotifyWaker<K> {
    fn wake(self: Arc<Self>) {
        // Call notify on the underlying Notify instance

        self.0.notify()
    }

    fn wake_by_ref(self: &Arc<Self>) {
        // Call notify on the underlying Notify instance
        self.0.notify()
    }
}

pub struct Notify<K: Kind> {
    key: Key<K>,
    task: AtomicPtr<Task<K>>,
    state: AtomicU8,
}

impl<K: Kind> Notify<K> {
    const EMPTY: u8 = 0;
    const WAITING: u8 = 1;
    const NOTIFIED: u8 = 2;

    pub fn new(key: Key<K>) -> Self {
        Self {
            key,
            task: AtomicPtr::default(),
            state: AtomicU8::new(Self::EMPTY),
        }
    }

    pub fn register(&self, task: Box<Task<K>>) -> bool {
        // Convert task to raw pointer
        let task_ptr = Box::into_raw(task);

        // Store task pointer and mark as waiting
        self.task.store(task_ptr, Release);

        self.state
            .compare_exchange(Self::EMPTY, Self::WAITING, AcqRel, Acquire)
            .is_ok()
    }

    pub fn notify(&self) {
        if self.state.swap(Self::NOTIFIED, AcqRel) == Self::WAITING {
            // Get task pointer
            let task_ptr = self.task.load(Acquire);
            if !task_ptr.is_null() {
                // Reconstruct box from raw pointer
                let task = unsafe { Box::from_raw(task_ptr) };
                block_on(K::schedule(*task))
            }
        }
    }
}

#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Key<K: Kind>(usize, PhantomData<K>);

impl<K: Kind> Key<K> {
    fn waker(&self) -> Waker {
        K::waker(*self)
    }
}

#[pin_project]
pub enum Act<K: Kind> {
    Call(ManuallyDrop<UnsafeCell<K::Call>>),
    Fut(#[pin] K::Fut),
    Coro(#[pin] K::Coro),
}

pub static KEY: AtomicUsize = AtomicUsize::new(0);

pub struct Task<K: Kind> {
    pub key: Key<K>,
    pub act: Option<Act<K>>,
}

enum Work {
    Local(Task<Local>),
    Remote(Task<Remote>),
}

impl Work {
    fn execute(mut self) -> Option<Self> {
        let poll = match &mut self {
            Work::Local(task) => {
                let Task { key, act } = task;
                match act {
                    Some(Act::Call(call)) => {
                        let func = unsafe { call.get().read() };
                        (func)();
                        Ready(())
                    }
                    Some(Act::Fut(fut)) => {
                        block_on(current_worker()).unwrap().waker = Some(key.waker().into());
                        let pinned = pin!(fut);
                        pinned.poll(&mut block_on(context()))
                    }
                    Some(Act::Coro(coro)) => {
                        block_on(current_worker()).unwrap().waker = Some(key.waker().into());
                        let pinned = pin!(coro);
                        pinned.poll_next(&mut block_on(context())).map(|_| ())
                    }
                    None => unreachable!(),
                }
            }
            Work::Remote(task) => {
                let Task { key, act } = task;
                match act {
                    Some(Act::Call(call)) => {
                        let func = unsafe { call.get().read() };
                        (func)();
                        Ready(())
                    }
                    Some(Act::Fut(fut)) => {
                        block_on(current_worker()).unwrap().waker = Some(key.waker().into());
                        let pinned = pin!(fut);
                        pinned.poll(&mut block_on(context()))
                    }
                    Some(Act::Coro(coro)) => {
                        block_on(current_worker()).unwrap().waker = Some(key.waker().into());
                        let pinned = pin!(coro);
                        pinned.poll_next(&mut block_on(context())).map(|_| ())
                    }
                    None => unreachable!(),
                }
            }
        };
        match (poll, &self) {
            (
                Pending,
                Work::Local(Task {
                    act: Some(Act::Fut(_)),
                    ..
                }),
            )
            | (
                Pending,
                Work::Remote(Task {
                    act: Some(Act::Fut(_)),
                    ..
                }),
            ) => Some(self),
            _ => None,
        }
    }
}

pub async fn waker() -> &'static mut Arc<Waker> {
    current_worker().await.unwrap().waker.as_mut().unwrap()
}

pub async fn context() -> Context<'static> {
    Context::from_waker(waker().await)
}

pub fn poll(
    cx: &mut std::task::Context<'_>,
    fut: impl IntoFuture<Output = ()>,
) -> std::task::Poll<()> {
    let fut = fut.into_future();
    pin!(fut).poll(cx)
}

const BLOCK_ON_VTABLE: RawWakerVTable = RawWakerVTable::new(
    |_| RawWaker::new(std::ptr::null(), &BLOCK_ON_VTABLE),
    |_| {},
    |_| {},
    |_| {},
);
pub const BLOCK_ON: &Waker =
    unsafe { &Waker::from_raw(RawWaker::new(std::ptr::null(), &BLOCK_ON_VTABLE)) };

pub struct Block<F> {
    future: Pin<Box<F>>,
    context: Context<'static>,
}

impl<F: Future> Block<F> {
    pub fn new(future: F) -> Self {
        Self {
            future: Box::pin(future),
            context: Context::from_waker(BLOCK_ON),
        }
    }
}

impl<F: Future> Block<F> {
    pub fn poll(&mut self) -> Poll<F::Output> {
        self.future.as_mut().poll(&mut self.context)
    }
}

pub fn block_on<F: Future>(mut future: F) -> F::Output {
    let mut fut = Block::new(future);
    loop {
        let Poll::Ready(x) = fut.poll() else {
            continue;
        };
        break x;
    }
}

pub struct YieldNow {
    yielded: Arc<AtomicBool>,
}

impl YieldNow {
    pub fn new() -> Self {
        Self {
            yielded: Arc::new(AtomicBool::new(false)),
        }
    }
}

impl Future for YieldNow {
    type Output = ();

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if self.yielded.load(Ordering::SeqCst) {
            Poll::Ready(())
        } else {
            let waker = cx.waker().clone();
            let yielded = self.yielded.clone();
            spawn_local(async move {
                yielded.store(true, Ordering::SeqCst);
                waker.wake();
            });
            Poll::Pending
        }
    }
}

pub fn yield_now() -> YieldNow {
    YieldNow::new()
}

#[pin_project]
pub struct Join<T: Future, U: Future> {
    #[pin]
    first: Pin<Box<T>>,
    #[pin]
    second: Pin<Box<U>>,
    first_done: bool,
    second_done: bool,
    first_result: Option<T::Output>,
    second_result: Option<U::Output>,
}

impl<T, U> Join<T, U>
where
    T: Future,
    U: Future,
{
    pub fn new(first: T, second: U) -> Self {
        Self {
            first: Box::pin(first),
            second: Box::pin(second),
            first_done: false,
            second_done: false,
            first_result: None,
            second_result: None,
        }
    }
}

impl<T, U> Future for Join<T, U>
where
    T: Future,
    U: Future,
{
    type Output = (T::Output, U::Output);

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // Poll first future if not done
        if !self.first_done {
            if let Poll::Ready(result) = self.first.as_mut().poll(cx) {
                self.first_done = true;
                self.first_result = Some(result);
            }
        }

        // Poll second future if not done
        if !self.second_done {
            if let Poll::Ready(result) = self.second.as_mut().poll(cx) {
                self.second_done = true;
                self.second_result = Some(result);
            }
        }

        // Return results if both are done
        if self.first_done && self.second_done {
            Poll::Ready((
                self.first_result.take().unwrap(),
                self.second_result.take().unwrap(),
            ))
        } else {
            Poll::Pending
        }
    }
}

// Utility functions to join futures
pub fn join<T, U>(first: T, second: U) -> Join<T, U>
where
    T: Future,
    U: Future,
{
    Join::new(first, second)
}

// Extension trait for more ergonomic usage
pub trait JoinExt: Future + Sized {
    fn join<U>(self, other: U) -> Join<Self, U>
    where
        U: Future,
    {
        Join::new(self, other)
    }
}

impl<F: Future> JoinExt for F {}

pub struct Select<T, U> {
    first: Pin<Box<T>>,
    second: Pin<Box<U>>,
    polled_first: bool,
    polled_second: bool,
}

#[derive(Debug)]
pub enum Either<T, U> {
    First(T),
    Second(U),
}

impl<T, U> Select<T, U>
where
    T: Future,
    U: Future,
{
    pub fn new(first: T, second: U) -> Self {
        Self {
            first: Box::pin(first),
            second: Box::pin(second),
            polled_first: false,
            polled_second: false,
        }
    }
}

impl<T, U> Future for Select<T, U>
where
    T: Future,
    U: Future,
{
    type Output = Either<T::Output, U::Output>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        // Try first future if not previously completed
        if !self.polled_first {
            match self.first.as_mut().poll(cx) {
                Poll::Ready(result) => return Poll::Ready(Either::First(result)),
                Poll::Pending => self.polled_first = true,
            }
        }

        // Try second future if not previously completed
        if !self.polled_second {
            match self.second.as_mut().poll(cx) {
                Poll::Ready(result) => return Poll::Ready(Either::Second(result)),
                Poll::Pending => self.polled_second = true,
            }
        }

        // Reset poll flags to try again next time
        self.polled_first = false;
        self.polled_second = false;

        Poll::Pending
    }
}

// Utility function for selecting between futures
pub fn select<T, U>(first: T, second: U) -> Select<T, U>
where
    T: Future,
    U: Future,
{
    Select::new(first, second)
}

// Extension trait for more ergonomic usage
pub trait SelectExt: Future + Sized {
    fn select<U>(self, other: U) -> Select<Self, U>
    where
        U: Future,
    {
        Select::new(self, other)
    }
}

impl<F: Future> SelectExt for F {}

#[derive(Deref, DerefMut, From)]
pub struct UnsafeLocal<T>(pub T);

unsafe impl<T> Send for UnsafeLocal<T> {}
unsafe impl<T> Sync for UnsafeLocal<T> {}

pub struct Handle<T>(Receiver<UnsafeLocal<T>>);

#[pin_project]
pub struct HandleRecv<T>(#[pin] flume::Receiver<UnsafeLocal<T>>);

impl<T> Future for HandleRecv<T> {
    type Output = T;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match self.project().0.try_recv() {
            Ok(value) => Poll::Ready(value.0),
            Err(flume::TryRecvError::Empty) => Poll::Pending,
            Err(flume::TryRecvError::Disconnected) => panic!("Channel closed unexpectedly"),
        }
    }
}

impl<T> IntoFuture for Handle<T> {
    type Output = T;
    type IntoFuture = HandleRecv<T>;

    fn into_future(self) -> Self::IntoFuture {
        HandleRecv(self.0)
    }
}

pub async fn spawn_generator<C: AsyncIterator<Item = ()> + 'static + Send>(coro: C) {
    let (tx, rx) = unbounded();
    let handle = Handle(rx.clone());

    let coro = async gen move {
        let pinned = pin!(coro);
        tx.send(UnsafeLocal(pinned.poll_next(&mut block_on(context()))));
        yield;
    };

    Remote::schedule(Task {
        key: Key(KEY.fetch_add(1, Ordering::AcqRel), PhantomData),
        act: Some(Act::Coro(
            Box::pin(coro) as Pin<Box<dyn AsyncIterator<Item = ()> + Send + 'static>>
        )),
    });
}

pub async fn spawn_blocking<F: FnOnce() -> T + Send + 'static + Clone, T: Send + 'static>(
    f: F,
) -> Handle<T> {
    let (tx, rx) = unbounded();
    let handle = Handle(rx.clone());
    let f = move || {
        tx.send(UnsafeLocal((f)()));
    };
    Remote::schedule(Task {
        key: Key(KEY.fetch_add(1, Ordering::AcqRel), PhantomData),
        act: Some(Act::Call(ManuallyDrop::new(UnsafeCell::new(
            Box::new(f) as Box<dyn FnOnce() + Send + 'static>
        )))),
    })
    .await;
    handle
}

pub async fn spawn<
    F: IntoFuture<Output = T, IntoFuture = Fut>,
    Fut: Future<Output = T> + Send + 'static,
    T: Send + 'static,
>(
    fut: F,
) -> Handle<T> {
    let (tx, rx) = unbounded();
    let handle = Handle(rx.clone());
    let fut = fut.into_future();
    let fut = async move || {
        tx.send(UnsafeLocal(fut.await));
    };
    Remote::schedule(Task {
        key: Key(KEY.fetch_add(1, Ordering::AcqRel), PhantomData),
        act: Some(Act::Fut(
            Box::pin((fut)()) as Pin<Box<dyn Future<Output = ()> + Send + 'static>>
        )),
    })
    .await;
    handle
}

pub async fn spawn_local<
    F: IntoFuture<Output = T, IntoFuture = Fut>,
    Fut: Future<Output = T> + 'static,
    T: 'static,
>(
    fut: F,
) -> Handle<T> {
    let (tx, rx) = unbounded();
    let handle = Handle(rx.clone());
    let fut = fut.into_future();
    let fut = async move || {
        tx.send(UnsafeLocal(fut.await));
    };
    Local::schedule(Task {
        key: Key(KEY.fetch_add(1, Ordering::AcqRel), PhantomData),
        act: Some(Act::Fut(
            Box::pin((fut)()) as Pin<Box<dyn Future<Output = ()> + 'static>>
        )),
    })
    .await;
    handle
}
