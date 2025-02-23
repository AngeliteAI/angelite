use crate::{
    component::{
        archetype::Archetype,
        registry::{Registry, Shard},
        table::Table,
    },
    world::World,
};
use base::{
    rt::{UnsafeLocal, block_on, spawn, spawn_blocking, worker::Register, yield_now},
    sync::{barrier::Barrier, oneshot::Oneshot},
};
use derive_more::derive::{Deref, DerefMut};
use ecs_macro::func;
use flume::{Receiver, Sender, bounded, unbounded};
use std::mem::offset_of;
use std::{
    any::{TypeId, type_name},
    clone,
    fmt::{self, Formatter},
    marker::PhantomData,
    pin::{Pin, pin},
    sync::Arc,
};

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
        Return {}
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
    Execute(Archetype, &'static mut Table),
    Complete,
}

unsafe impl Send for Cmd {}

pub struct Get<T: Params<'static>> {
    get: Receiver<Cmd>,
    marker: PhantomData<T>,
}

pub struct Finished;

impl<T: Params<'static>> AsyncFnOnce<()> for Get<T> {
    type CallOnceFuture = Getter<T>;

    type Output = Result<T, Finished>;

    extern "rust-call" fn async_call_once(self, args: ()) -> Self::CallOnceFuture {
        Getter {
            fut: Box::pin(async move {
                loop {
                    match self.get.try_recv() {
                        Ok(Cmd::Execute(supertype, table)) => {
                            return Ok(T::create(supertype, table));
                        }
                        Ok(Cmd::Complete) => return Err(Finished),
                        Err(flume::TryRecvError::Empty) => yield_now().await,
                        Err(_) => panic!("failure to retrieve system param information"),
                    }
                }
            }),
        }
    }
}

pub struct Getter<T: Params<'static>> {
    fut: Pin<Box<dyn Future<Output = Result<T, Finished>> + Send>>,
}

impl<T: Params<'static>> Future for Getter<T> {
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
}
impl Put {
    pub(crate) fn prepare(&self, registry: &mut Registry) {
        dbg!(self.put.is_disconnected());
        let mut binding = (self.binding)(registry);
        dbg!(self.put.is_disconnected());
        for (supertype, table) in binding.table_vec().unwrap().drain(..) {
            dbg!(&supertype);
            self.put
                .clone()
                .try_send(Cmd::Execute(supertype, table)).unwrap();
        }
        dbg!(self.put.is_disconnected());
    }
}

pub trait Wrap<Input, Marker: Provider>: Func<Input, Marker> {
    fn wrap(self) -> (System, Receiver<Cmd>, Put);
}

impl<Input: Params<'static>, Output: Outcome, F: Func<Input, Blocking<Output>> + Clone>
    Wrap<Input, Blocking<Output>> for F
{
    fn wrap(mut self) -> (System, Receiver<Cmd>, Put) {
        let (tx, rx) = unbounded();
        let binding = Arc::new(Input::bind);
        let system = Box::pin(move |get: Receiver<Cmd>| {
            let this = self.clone();
            let system = block_on(spawn_blocking(move || {
                block_on(async move {
                    Ok(this
                        .derive()
                        .execute(
                            (Get::<Input> {
                                get,
                                marker: PhantomData,
                            })
                            .async_call_once(())
                            .await?,
                        )
                        .await
                        .to_return())
                })
            }));
            system
        });
        dbg!(rx.is_disconnected());
        (system, rx, Put { binding, put: tx })
    }
}

impl<F, Fut: Future<Output = R> + Send, R: Outcome + Send, Input: Params<'static>>
    Wrap<Input, Concurrent<Fut>> for F
where
    F: Func<Input, Concurrent<Fut>> + Clone,
{
    fn wrap(mut self) -> (System, Receiver<Cmd>, Put) {
        let (tx, rx) = unbounded();
        let binding = Arc::new(Input::bind);

        let system = Box::pin(move |get: Receiver<Cmd>| {
            let this = self.clone();
            let system = block_on(spawn(async move {
                Ok(this
                    .derive()
                    .execute(
                        (Get::<Input> {
                            get,
                            marker: PhantomData,
                        })()
                        .await?,
                    )
                    .await
                    .to_return())
            }));
            system
        });
        (system, rx, Put { binding, put: tx })
    }
}
ecs_macro::func!();
