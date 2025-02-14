use std::{
    cell::UnsafeCell,
    marker::PhantomData,
    sync::{
        Arc, OnceLock,
        atomic::{AtomicUsize, Ordering::*},
    },
    task::Waker,
    thread::{self, Thread},
};

use crate::{
    collections::{bi::BiMap, queue::Queue, skip::Map},
    prelude::Vector,
    rng::{Branch, Pcg, Random, Range, rng},
    sync::{barrier::Barrier, thread_local},
    time::TimerWheel,
};

use super::{JoinExt, Key, Local, Remote, SelectExt, Task, Work, block_on};

static WORKERS: thread_local::Local<Worker> = thread_local::Local::new();
static REMOTE_COUNTER: AtomicUsize = AtomicUsize::new(0);

pub trait Register {
    async fn register(&self, worker: Worker);
}

impl Register for Thread {
    async fn register(&self, worker: Worker) {
        WORKERS.init_for_thread(self, worker).await;
    }
}

#[derive(Debug, Clone, Copy, Hash, Eq, PartialEq, PartialOrd, Ord, Default)]
pub struct WorkerId(usize);

pub struct Worker {
    pub rng: Pcg<4>,
    pub waker: Option<Arc<Waker>>,
    pub timers: TimerWheel,
    pub local: Queue<Task<Local>>,
    pub local_counter: AtomicUsize,
    pub remote: Queue<Task<Remote>>,
}

impl Worker {
    pub async fn work() {
        let Some(me) = current_worker().await else {
            thread::yield_now();
            return;
        };
        me.timers.tick().await;
        let Some(mut work) = next_work().await else {
            thread::yield_now();
            return;
        };
        work.execute();
    }
    async fn dequeue(&mut self) -> Option<Work> {
        if let Some(task) = self.local.dequeue() {
            return Some(Work::Local(task));
        }
        if let Some(task) = self.remote.dequeue() {
            return Some(Work::Remote(task));
        }
        None
    }
}

pub async fn worker_start_barrier(start: Arc<Barrier>) {
    start
        .wait()
        .select(async move {
            loop {
                Worker::work().await;
            }
        })
        .await;
}

pub struct WorkerHandle(thread::JoinHandle<()>);

pub async fn start(seed: Vector<4, u128>, worker_count: usize) -> Arc<Barrier> {
    let mut rng = Pcg::<4>::new(seed);
    let start = Arc::new(Barrier::new(worker_count + 1));
    thread::current()
        .register(Worker {
            rng: rng.branch(),
            timers: TimerWheel::new(),
            waker: None,
            local_counter: 0.into(),
            local: Queue::default(),
            remote: Queue::default(),
        })
        .await;

    for worker in (0..worker_count).map(|x| x + 1).map(WorkerId) {
        let start = start.clone();
        let handle = thread::spawn(move || {
            block_on(async {
                worker_start_barrier(start).await;
                Worker::work().await;
            })
        });
        handle
            .thread()
            .register(Worker {
                timers: TimerWheel::new(),
                rng: rng.branch(),
                waker: None,
                local_counter: 0.into(),
                local: Queue::default(),
                remote: Queue::default(),
            })
            .await;
    }

    start
}

async fn next_work() -> Option<Work> {
    let worker = current_worker().await;
    match worker.unwrap().dequeue().await {
        Some(x) => Some(x),
        None => steal_work().await,
    }
}

pub async fn select_worker() -> &'static Worker {
    all_workers().await.next().unwrap()
}

async fn all_workers() -> impl Iterator<Item = &'static Worker> + Clone {
    //SAFETY ?????????????
    let workers = WORKERS.all_values().collect::<Vec<_>>();
    workers
        .into_iter()
        .cycle()
        .skip(
            rng()
                .await
                .map(|x| x.sample(&Range::new(0..WORKERS.len())))
                .unwrap_or_default(),
        )
        .take(WORKERS.len())
}

async fn steal_work() -> Option<Work> {
    const RETRIES: usize = 5;
    for _ in 0..RETRIES {
        let worker = select_worker().await;
        if let Some(task) = worker.remote.dequeue() {
            return Some(Work::Remote(task));
        }
    }
    None
}

pub async fn current_worker() -> Option<&'static mut Worker> {
    WORKERS.get_mut().await
}

pub async fn next_local_key() -> Key<Local> {
    Key(
        current_worker()
            .await
            .map(|x| x.local_counter.fetch_add(1, Relaxed))
            .unwrap_or_default(),
        PhantomData,
    )
}

pub async fn next_remote_key() -> Key<Remote> {
    Key(REMOTE_COUNTER.fetch_add(1, Relaxed), PhantomData)
}
