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
    sync::thread_local,
};

use super::{Key, Local, Remote, Task, Work, block_on};

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
    pub local: Queue<Task<Local>>,
    pub local_counter: AtomicUsize,
    pub remote: Queue<Task<Remote>>,
}

impl Worker {
    async fn work() {
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

pub async fn start(seed: Vector<4, u128>, count: usize) {
    let mut rng = Pcg::<4>::new(seed);
    thread::current()
        .register(Worker {
            rng: rng.branch(),
            waker: None,
            local_counter: 0.into(),
            local: Queue::default(),
            remote: Queue::default(),
        })
        .await;
    dbg!("yo3");

    for worker in (0..count).map(|x| x + 1).map(WorkerId) {
        let handle = thread::spawn(|| {
            block_on(Worker::work());
        });
        handle
            .thread()
            .register(Worker {
                rng: rng.branch(),
                waker: None,
                local_counter: 0.into(),
                local: Queue::default(),
                remote: Queue::default(),
            })
            .await;
    }
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
