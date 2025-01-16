use std::{
    cell::{OnceCell, UnsafeCell},
    marker::PhantomData,
    mem::{self, ManuallyDrop},
    pin::{Pin, pin},
    sync::{
        Arc, OnceLock,
        atomic::{AtomicPtr, AtomicU8, Ordering::*},
    },
    task::{
        Context,
        Poll::{self, *},
        RawWaker, RawWakerVTable, Wake, Waker,
    },
};

use pin_project::pin_project;
use worker::{current_worker, select_worker};

use crate::{collections::queue::Queue, sync::split::Split};

pub mod worker;

#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Local;
#[derive(Debug, Copy, Clone, Eq, PartialEq, Hash)]
pub struct Remote;

pub trait Kind: Copy {
    type Call;
    type Fut;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized;
    fn schedule(task: Task<Self>);
}

impl Kind for Local {
    type Call = Box<dyn FnOnce()>;
    type Fut = Pin<Box<dyn Future<Output = ()>>>;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized,
    {
        // Create notify handle
        let notify = Arc::new(Notify::new(id));

        Waker::from(Arc::new(NotifyWaker(notify)))
    }

    fn schedule(task: Task<Self>) {
        block_on(current_worker()).unwrap().local.enqueue(task);
    }
}

impl Kind for Remote {
    type Call = Box<dyn FnOnce() + Send>;
    type Fut = Pin<Box<dyn Future<Output = ()> + Send>>;

    fn waker(id: Key<Self>) -> Waker
    where
        Self: Sized,
    {
        // Create notify handle
        let notify = Arc::new(Notify::new(id));

        Waker::from(Arc::new(NotifyWaker(notify)))
    }

    fn schedule(task: Task<Self>) {
        block_on(select_worker()).remote.enqueue(task);
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
                K::schedule(*task)
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
}

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
