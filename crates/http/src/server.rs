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

    #[component(dyn Code)]
    pub struct Ok;
    #[component(dyn Code)]
    pub struct NotFound;

    #[component(Ok, NotFound)]
    pub trait Code: 'static + Component {
        fn name(&self) -> &'static str;
        fn code(&self) -> u16;
    }

    impl Code for Ok {
        fn name(&self) -> &'static str { "Ok "}
        fn code(&self) -> u16 {
            200
        }
    }

    impl Code for NotFound {
        fn name(&self) -> &'static str { "NotFound "}
        fn code(&self) -> u16 {
            404
        }
    }
}

pub fn sysa(query: Query<'_, &'_ dyn Code>) {
    let mut count = 0;
    for code in &query {
        println!("{}", code.0.code())
    }
}

#[component]
pub struct Request;

#[derive(Debug)]
#[component]
pub struct Pending;

pub struct Router {}
pub async fn serve(router: Router) {
    let mut world = World::default();
    for i in 0..10000 {
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
