use std::{iter, marker::PhantomData};

use base::collections::arrayvec::ArrayVec;

use super::{
    func::{Blocking, Concurrent, Func, Id, Outcome, Provider},
    graph::{Graph, Require},
    param::Params,
};

pub trait Sequence<Marker: Provider> {
    type Input;
    type Output;
    type Return: Params<'static> + Send;
    fn transform(self, graph: &mut Graph);
    fn iter(&self) -> impl Iterator<Item = Id>;
    fn before<Rhs: Sequence<Other>, Other: Provider>(
        self,
        rhs: Rhs,
    ) -> Before<Self, Rhs, Marker, Other>
    where
        Self: Sized,
    {
        Before(self, rhs, PhantomData)
    }
    fn pipe<Rhs: Sequence<Other, Input = Self::Return>, Other: Provider>(
        self,
        rhs: Rhs,
    ) -> Pipe<Self, Rhs, Marker, Other>
    where
        Self: Sized,
    {
        Pipe(self, rhs, PhantomData)
    }
}

pub struct System<Input, Output, Marker>(PhantomData<(Input, Output, Marker)>);

impl<Input, Output, Marker: Provider> Provider for System<Input, Output, Marker> {
    type Return = Marker::Return;
}

pub struct Before<Lhs: Sequence<A>, Rhs: Sequence<B>, A: Provider, B: Provider>(
    Lhs,
    Rhs,
    PhantomData<(A, B)>,
);
impl<Lhs: Sequence<A>, Rhs: Sequence<B>, A: Provider, B: Provider> Provider
    for Before<Lhs, Rhs, A, B>
{
    type Return = A::Return;
}
pub struct Pipe<Lhs: Sequence<A>, Rhs: Sequence<B, Input = Lhs::Return>, A: Provider, B: Provider>(
    Lhs,
    Rhs,
    PhantomData<(A, B)>,
);
impl<Lhs: Sequence<A>, Rhs: Sequence<B, Input = Lhs::Return>, A: Provider, B: Provider> Provider
    for Pipe<Lhs, Rhs, A, B>
{
    type Return = A::Return;
}
pub struct Set<Tuple>(Tuple);

//meshpipe_macro::set!();

impl<
    Input: Params<'static>,
    Output: Future<Output = R> + Send,
    R: Outcome + Params<'static> + Send,
    F: Func<Input, Concurrent<Output>> + Clone,
> Sequence<System<Input, R, Concurrent<Output>>> for F
{
    type Input = Input;
    type Output = Output;
    type Return = R;

    fn transform(self, graph: &mut Graph) {
        graph.register::<Input, Concurrent<Output>>(self);
    }

    fn iter(&self) -> impl Iterator<Item = Id> {
        iter::once(self.id())
    }
}
impl<
    F: Func<Input, Blocking<Output>> + Clone,
    Input: Params<'static>,
    Output: Params<'static> + Outcome,
> Sequence<System<Input, Output, Blocking<Output>>> for F
{
    type Input = Input;
    type Output = Output;
    type Return = <Blocking<Output> as Provider>::Return;

    fn transform(self, graph: &mut Graph) {
        graph.register(self);
    }

    fn iter(&self) -> impl Iterator<Item = Id> {
        iter::once(self.id())
    }
}

impl<Lhs: Sequence<A>, Rhs: Sequence<B>, A: Provider, B: Provider> Sequence<Self>
    for Before<Lhs, Rhs, A, B>
{
    type Input = Lhs::Input;
    type Output = Lhs::Output;
    type Return = Lhs::Return;

    fn transform(self, graph: &mut Graph) {
        let Before(lhs, rhs, _) = self;
        let requirements = lhs
            .iter()
            .flat_map(|lhs| rhs.iter().map(move |rhs| (lhs, rhs)))
            .map(|(dependency, dependent)| Require::Depend {
                dependent,
                dependency,
            })
            .collect::<ArrayVec<_, 16>>();
        lhs.transform(graph);
        rhs.transform(graph);
        requirements.into_iter().for_each(|req| graph.require(req));
    }

    fn iter(&self) -> impl Iterator<Item = Id> {
        let Before(lhs, rhs, _) = self;
        lhs.iter().chain(rhs.iter())
    }
}

impl<Lhs: Sequence<A>, Rhs: Sequence<B, Input = Lhs::Return>, A: Provider, B: Provider>
    Sequence<Self> for Pipe<Lhs, Rhs, A, B>
{
    type Input = Lhs::Input;
    type Output = Rhs::Output;
    type Return = Rhs::Return;

    fn transform(self, graph: &mut Graph) {
        todo!()
    }

    fn iter(&self) -> impl Iterator<Item = Id> {
        iter::empty()
    }
}
