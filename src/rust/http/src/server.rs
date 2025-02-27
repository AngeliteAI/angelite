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

    macro_rules! codes {
            (
                $(
                    $(#[$attr:meta])*
                    $variant_name:ident = $code_value:expr
                ),* $(,)?
            ) => {
                // Define the CodeTrait trait.
                #[component($($variant_name),*)]
                pub trait Code: 'static + Component {
                    fn code(&self) -> u16;
                    fn reason(&self) -> &'static str;
                }

                // Define the code structs and implement the trait.
                $(
                    $(#[$attr])*
                    #[component(dyn Code)]
                    #[derive(Debug)]
                    pub struct $variant_name;

                    impl Code for $variant_name {
                        fn code(&self) -> u16 {
                            $code_value
                        }
                        fn reason(&self) -> &'static str {
                            stringify!($variant_name)
                        }
                    }
                )*
            };
        }

    // Usage: Define ALL standard HTTP status codes
    codes! {
        // 1xx: Informational
        Continue = 100,
        SwitchingProtocols = 101,
        Processing = 102,
        EarlyHints = 103,

        // 2xx: Success
        Ok = 200,
        Created = 201,
        Accepted = 202,
        NonAuthoritativeInformation = 203,
        NoContent = 204,
        ResetContent = 205,
        PartialContent = 206,
        MultiStatus = 207,
        AlreadyReported = 208,
        IMUsed = 226,

        // 3xx: Redirection
        MultipleChoices = 300,
        MovedPermanently = 301,
        Found = 302,
        SeeOther = 303,
        NotModified = 304,
        UseProxy = 305,
        // 306 is reserved
        TemporaryRedirect = 307,
        PermanentRedirect = 308,

        // 4xx: Client Error
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
        URITooLong = 414,
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

        // 5xx: Server Error
        InternalServerError = 500,
        NotImplemented = 501,
        BadGateway = 502,
        ServiceUnavailable = 503,
        GatewayTimeout = 504,
        HTTPVersionNotSupported = 505,
        VariantAlsoNegotiates = 506,
        InsufficientStorage = 507,
        LoopDetected = 508,
        NotExtended = 510,
        NetworkAuthenticationRequired = 511,
    }
}

pub fn sysa(query: Query<'_, &'_ dyn Code>) {
    let mut count = 0;
    let mut deez = 0;
    for code in &query {
        if code.0.reason().starts_with("Ok") {
            count += 1;
        } else if code.0.reason().starts_with("NotFound") {
            deez += 1;
        }
    }
    println!("Ok: {}, NotFound: {}", count, deez);
}

#[component]
pub struct Request;

#[derive(Debug)]
#[component]
pub struct Pending;

pub struct Router {}
pub async fn serve(router: Router) {
    let mut world = World::default();
    let mut schedule = Schedule::default().schedule(sysa);
    schedule.run(&mut world).await;
}
