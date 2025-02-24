use base::rng::Random;
use base::sync::mutex::Queue;
use ecs::component::component;
use ecs::query::Query;
use ecs::schedule::Schedule;
use ecs::system::func::{Blocking, Func, Wrap};
use ecs::{component::Component, world::World};
use status::Code;
use std::future::pending;

mod status {
    use ecs::component::{Component, access::Access, component};

    #[component]
    pub struct Ok;
    #[component]
    pub struct NotFound;

    #[component(Ok, NotFound)]
    pub trait Code {}

    impl Code for Ok {}

    impl Code for NotFound {}
}

#[component]
pub struct Request;

#[derive(Debug)]
#[component]
pub struct Pending;

pub struct Router {}

pub fn get() {}

pub fn post() {}

pub fn put() {}

pub fn delete() {}

pub fn patch() {}

pub fn head() {}

pub fn options() {}

pub fn sysa(query: Query<&'static dyn Code>) {
    for (i, code) in query.into_iter().enumerate() {
        println!("{i}");
        //do http stuff
    }
}

pub async fn serve(router: Router) {
    let mut world = World::default();
    for i in 0..1000 {
        if base::rng::rng()
            .await
            .unwrap()
            .sample::<bool>(&base::rng::Standard)
        {
            world.extend([(status::Ok,)])
        } else {
            world.extend([(status::NotFound,)])
        }
    }
    let mut schedule = Schedule::default().schedule(sysa);
    schedule.run(&mut world).await;
}
