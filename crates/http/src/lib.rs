use base::sync::mutex::Queue;
use ecs::query::Query;
use ecs::schedule::Schedule;
use ecs::system::func::{Blocking, Func, Wrap};
use ecs::{component::Component, world::World};
use std::future::pending;

mod status {
    use ecs::component::Component;

    pub trait Code: Component {
        fn status_code(&self) -> u16;
    }

    macro_rules! status_codes {
        ($($name:ident = $code:expr),*) => {
            $(
                #[derive(Component, Copy, Clone, Debug)]
                pub struct $name;

                impl Code for $name {
                    #[inline(always)]
                    fn status_code(self) -> u16 {
                        $code
                    }
                }
            )*
        }
    }

    // Define all standard HTTP status codes
    status_codes! {
        // 1xx Informational
        Continue = 100,
        SwitchingProtocols = 101,
        Processing = 102,
        EarlyHints = 103,

        // 2xx Success
        Ok = 200,
        Created = 201,
        Accepted = 202,
        NonAuthoritativeInformation = 203,
        NoContent = 204,
        ResetContent = 205,
        PartialContent = 206,
        MultiStatus = 207,
        AlreadyReported = 208,
        ImUsed = 226,

        // 3xx Redirection
        MultipleChoices = 300,
        MovedPermanently = 301,
        Found = 302,
        SeeOther = 303,
        NotModified = 304,
        UseProxy = 305,
        TemporaryRedirect = 307,
        PermanentRedirect = 308,

        // 4xx Client Error
        BadRequest = 400,
        Unauthorized = 401,
        PaymentRequired = 402,
        Forbidden = 403,
        NotFound = 404,
        MethodNotAllowed = 405,
        NotAcceptable = 406,
        ProxyAuthenticationRequired = 407,
        RequestTimeout = 408,
        Conflict = 409,
        Gone = 410,
        LengthRequired = 411,
        PreconditionFailed = 412,
        PayloadTooLarge = 413,
        UriTooLong = 414,
        UnsupportedMediaType = 415,
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
        RequestHeaderFieldsTooLarge = 431,
        UnavailableForLegalReasons = 451,

        // 5xx Server Error
        InternalServerError = 500,
        NotImplemented = 501,
        BadGateway = 502,
        ServiceUnavailable = 503,
        GatewayTimeout = 504,
        HttpVersionNotSupported = 505,
        VariantAlsoNegotiates = 506,
        InsufficientStorage = 507,
        LoopDetected = 508,
        NotExtended = 510,
        NetworkAuthenticationRequired = 511
    }
}

#[derive(Component)]
pub struct Request;
#[derive(Component, Debug)]
pub struct Pending;

fn sysa(deez: Query<(&dyn status::Code)>) {
    for (i, _) in deez.into_iter().enumerate() {
        println!("{i:?}");
    }
}

pub async fn start() {
    let mut world = World::default();

    world.extend((0..100).map(|_| (Request, Pending)));
    dbg!("yo hoe");
    let mut schedule = Schedule::default().schedule(sysa);
    schedule.run(&mut world).await;
}
