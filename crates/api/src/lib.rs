use base::sync::mutex::Queue;
use ecs::query::Query;
use ecs::schedule::Schedule;
use ecs::system::func::{Blocking, Func, Wrap};
use ecs::{component::Component, world::World};

#[repr(u16)]
pub enum Success {
    Ok = 200,
    Created = 201,
    Accepted = 202,
    NonAuthInfo = 203,
    NoContent = 204,
    ResetContent = 205,
    PartialContent = 206,
    MultiStatus = 207,
    AlreadyReported = 208,
    ImUsed = 226,

    MultipleChoices = 300,
    MovedPermanently = 301,
    Found = 302,
    SeeOther = 303,
    NotModified = 304,
    UseProxy = 305,
    TemporaryRedirect = 307,
    PermanentRedirect = 308,
}

#[repr(u16)]
pub enum Error {
    BadRequest = 400,
    Unauthorized = 401,
    PaymentRequired = 402,
    Forbidden = 403,
    NotFound = 404,
    MethodNotAllowed = 405,
    NotAcceptable = 406,
    ProxyAuthRequired = 407,
    RequestTimeout = 408,
    Conflict = 409,
    Gone = 410,
    LengthRequired = 411,
    PreconditionFailed = 412,
    PayloadTooLarge = 413,
    UriTooLong = 414,
    UnsupportedMedia = 415,
    RangeNotSatisfiable = 416,
    ExpectationFailed = 417,
    ImATeapot = 418,
    MisdirectedRequest = 421,
    UnprocessableEntity = 422,
    Locked = 423,
    FailedDependency = 424,
    TooEarly = 425,
    UpgradeRequired = 426,
    PreconditionRequired = 428,
    TooManyRequests = 429,
    HeaderFieldsTooLarge = 431,
    UnavailableLegal = 451,

    InternalError = 500,
    NotImplemented = 501,
    BadGateway = 502,
    ServiceUnavailable = 503,
    GatewayTimeout = 504,
    HttpVersionNotSupported = 505,
    VariantAlsoNegotiates = 506,
    InsufficientStorage = 507,
    LoopDetected = 508,
    NotExtended = 510,
    NetworkAuthRequired = 511,
}

#[derive(Component)]
pub struct Request;
#[derive(Component, Debug)]
pub struct Pending(isize);
#[derive(Component)]
pub struct Complete(Success);
#[derive(Component)]
pub struct Failure(Error);

fn sysa(deez: Query<(&Pending)>) {
    for i in &deez {
        println!("{i:?}");
    }
}

pub async fn start() {
    let mut world = World::default();

    world.extend((0..1000).map(|x| ((3 * x + 17) / 4 + 10)).map(Pending));
    dbg!("yo hoe");
    let mut schedule = Schedule::default().schedule(sysa);
    schedule.run(&mut world).await.await;
}
