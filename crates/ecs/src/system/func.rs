use crate::{
    component::{
        archetype::Archetype,
        registry::{Registry, Shard},
        table::Table,
    },
    world::World,
};
use base::{
    rt::{UnsafeLocal, block_on, spawn, spawn_blocking, worker::Register},
    sync::{barrier::Barrier, oneshot::Oneshot},
};
use derive_more::derive::{Deref, DerefMut};
use ecs_macro::func;
use flume::{Receiver, Sender, unbounded};
use std::mem::offset_of;
use std::{any::{TypeId, type_name}, clone, fmt::{self, Formatter}, marker::PhantomData, pin::{Pin, pin}, sync::Arc};

use super::{System, param::Params};

#[derive(Copy, Clone, Ord, PartialOrd, Eq, PartialEq, Hash, Deref, DerefMut)]
pub struct Id(pub TypeId);

impl fmt::Debug for Id {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        let Self(id) = self;
        let name = &format!("{id:#?}");
        let name = name.trim_start_matches("TypeId(");
        let name = name.trim_end_matches(")");
        f.write_str(name)
    }
}

pub trait Provider {
    type Return;
}

pub trait Func<Input, Marker: Provider>: Send + 'static {
    fn derive(&self) -> Self
    where
        Self: Sized;
    fn execute(self, get: Input) -> impl Future<Output = Marker::Return> + Send
    where
        Self: Sized;
    fn id(&self) -> Id {
        Id(typeid::of::<Self>())
    }
    fn name(&self) -> &'static str {
        type_name::<Self>()
    }
}

pub trait Outcome: Send + 'static {
    fn to_return(self) -> Return;
}

impl Outcome for () {
    fn to_return(self) -> Return {
        todo!()
    }
}

impl Outcome for (i32,) {
    fn to_return(self) -> Return {
        Return {}
    }
}

pub struct Return {}

pub struct Concurrent<T> {
    marker: PhantomData<(T)>,
}
pub struct Blocking<T> {
    marker: PhantomData<(T)>,
}

impl<T> Provider for Blocking<T> {
    type Return = T;
}

impl<Fut: Future> Provider for Concurrent<Fut> {
    type Return = Fut::Output;
}

type Erased = u8;

pub enum Cmd {
    Execute(Archetype, Table),
    Complete,
}

unsafe impl Send for Cmd {}

pub struct Get<T: Params> {
    get: Arc<Receiver<Cmd>>,
    marker: PhantomData<T>,
}

impl<T: Params> Clone for Get<T> {
    fn clone(&self) -> Self {
        Self {
            get: self.get.clone(),
            marker: PhantomData,
        }
    }
}

pub struct Finished;

impl<T: Params> AsyncFnOnce<()> for Get<T> {
    type CallOnceFuture = Getter<T>;

    type Output = Result<T, Finished>;

    extern "rust-call" fn async_call_once(self, args: ()) -> Self::CallOnceFuture {
        self.async_call(args)
    }
}

impl<T: Params> AsyncFnMut<()> for Get<T> {
    type CallRefFuture<'a>
    where
        Self: 'a,
    = Getter<T>;

    extern "rust-call" fn async_call_mut(&mut self, args: ()) -> Self::CallRefFuture<'_> {
        self.async_call(args)
    }
}

impl<T: Params> AsyncFn<()> for Get<T> {
    extern "rust-call" fn async_call(&self, args: ()) -> Self::CallOnceFuture {
        let get = self.get.clone();
        Getter {
            fut: Box::pin(async move {
                match get.try_recv() {
                    Ok(Cmd::Execute(supertype, table)) => Ok(T::create(supertype, table)),
                    Ok(Cmd::Complete) => Err(Finished),
                    Err(_) => panic!("failure to retrieve system param information"),
                }
            }),
        }
    }
}

pub struct Getter<T: Params> {
    fut: Pin<Box<dyn Future<Output = Result<T, Finished>> + Send>>,
}

impl<T: Params> Future for Getter<T> {
    type Output = Result<T, Finished>;

    fn poll(
        mut self: Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        let fut = pin!(&mut self.fut);
        let poll = fut.poll(cx);
        poll
    }
}

pub struct Put {
    binding: Arc<dyn Fn(&mut Registry) -> Shard>,
    put: Sender<Cmd>,
    hold: Arc<Receiver<Cmd>>,
}
impl Put {
    pub(crate) fn prepare(&self, registry: &mut Registry) {
        let mut binding = (self.binding)(registry);
        for (supertype, table) in binding.table_vec().unwrap().drain(..) {
            self.put.clone().try_send(Cmd::Execute(supertype, table));
        }
    }
}

pub trait Wrap<Input, Marker: Provider>: Func<Input, Marker> {
    fn wrap(self) -> (System, Put);
}

impl<Input: Params, Output: Outcome, F: Func<Input, Blocking<Output>> + Clone>
    Wrap<Input, Blocking<Output>> for F
{
    fn wrap(mut self) -> (System, Put) {
        let (get, put) = bind::<Input>();
        let pkg = (self, get);
        let system = Box::pin(move || {
            let pkg = pkg.clone();
            let system = block_on(spawn_blocking(move || {
                let pkg = pkg.clone();
                block_on(async move {
                    let (func, get) = pkg.clone();
                    Ok(func
                        .derive()
                        .execute(get.async_call(()).await?)
                        .await
                        .to_return())
                })
            }));
            system
        });
        (system, put)
    }
}

impl<F, Fut: Future<Output = R> + Send, R: Outcome + Send, Input: Params>
    Wrap<Input, Concurrent<Fut>> for F
where
    F: Func<Input, Concurrent<Fut>> + Clone,
{
    fn wrap(mut self) -> (System, Put) {
        let (get, put) = bind();
        let system = Box::pin(move || {
            let get = get.clone();
            let this = self.clone();
            let system = block_on(spawn(async move {
                Ok(this.derive().execute((get)().await?).await.to_return())
            }));
            system
        });
        (system, put)
    }
}
ecs_macro::func!();

fn bind<T: Params>() -> (Get<T>, Put) {
    let (put, get) = unbounded();
    let get = Arc::from(get);
    let hold = get.clone();
    let binding = Arc::new(T::bind);
    (
        Get {
            get: get,
            marker: PhantomData,
        },
        Put { binding, put, hold },
    )
}
