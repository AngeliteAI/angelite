#![feature(trait_alias)]
use derive_more::Display;
use http::{Request, Response, StatusCode};
use hyper::body::{Body, Bytes};
use hyper::rt as hyper_rt;
use hyper::service::HttpService;
use pin_project::pin_project;
use std::{future::Future, marker::PhantomData, pin::Pin};
use tower::ServiceExt;

mod rt;

#[derive(Debug, Display)]
pub struct Error;

impl std::error::Error for Error {}

unsafe impl Send for Error {}
unsafe impl Sync for Error {}

pub type Result<T, E = Error> = std::result::Result<T, E>;

pub struct Service<R> {
    router: Option<R>,
}

pub fn wrap_tokio(
    io: impl tokio::io::AsyncRead + tokio::io::AsyncWrite,
) -> impl hyper_rt::Read + hyper_rt::Write {
    rt::Io(io)
}

impl<R> Service<R>
where
    R: Router,
{
    pub fn make(router: R) -> Self {
        Self {
            router: Some(router),
        }
    }

    pub async fn serve(&mut self, io: impl hyper_rt::Read + hyper_rt::Write + Unpin) {
        let adapter = RouterAdapter::new(self.router.take().unwrap());
        let conn = hyper::server::conn::http1::Builder::new().serve_connection(io, adapter);

        conn.await.ok();
    }
}

// Adapter to bridge Router trait to hyper's Service trait
pub struct RouterAdapter<R> {
    router: R,
}

impl<R: Router> RouterAdapter<R> {
    pub fn new(router: R) -> Self {
        Self { router }
    }
}

impl<R: Router> hyper::service::Service<Request<hyper::body::Incoming>> for RouterAdapter<R> {
    type Response = Response<String>;
    type Error = hyper::Error;
    type Future =
        std::pin::Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn call(&self, req: Request<hyper::body::Incoming>) -> Self::Future {
        let routing = self.router.handle(req);
        Box::pin(async move {
            match routing.await {
                Ok(response) => Ok(response),
                Err(_) => {
                    let response = Response::builder()
                        .status(StatusCode::INTERNAL_SERVER_ERROR)
                        .body(String::from("Internal Server Error"))
                        .unwrap();
                    Ok(response)
                }
            }
        })
    }
}

pub trait Router: Send + Sync {
    fn ready(&mut self, cx: &mut std::task::Context<'_>) -> std::task::Poll<Result<()>>;

    fn handle(&self, request: Request<hyper::body::Incoming>) -> Routing;

    fn can_handle(&self, method: http::Method, path: &str) -> bool;
}

#[pin_project]
pub struct Routing {
    #[pin]
    inner: Pin<Box<dyn Future<Output = Result<Response<String>>> + Send>>,
}

impl Routing {
    pub fn from_future<F>(future: F) -> Self
    where
        F: Future<Output = Result<Response<String>>> + Send + 'static,
    {
        Self {
            inner: Box::pin(future),
        }
    }
}

impl Future for Routing {
    type Output = Result<Response<String>>;

    fn poll(
        self: Pin<&mut Self>,
        cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Self::Output> {
        self.project().inner.poll(cx)
    }
}
impl<R: Router> tower::Service<Request<hyper::body::Incoming>> for Service<R> {
    type Response = Response<String>;

    type Error = Error;

    type Future = Routing;

    fn poll_ready(&mut self, cx: &mut std::task::Context<'_>) -> std::task::Poll<Result<()>> {
        match &mut self.router {
            Some(router) => router.ready(cx),
            None => std::task::Poll::Ready(Err(Error)),
        }
    }

    fn call(&mut self, req: hyper::Request<hyper::body::Incoming>) -> Self::Future {
        match &self.router {
            Some(router) => router.handle(req),
            None => Routing::from_future(async { Err(Error) }),
        }
    }
}
pub type HandlerFn = Box<dyn Fn(Request<hyper::body::Incoming>) -> Routing + Send + Sync>;

pub struct GetHandler(HandlerFn);
pub struct PostHandler(HandlerFn);
pub struct PutHandler(HandlerFn);
pub struct DeleteHandler(HandlerFn);
pub struct PatchHandler(HandlerFn);
pub struct HeadHandler(HandlerFn);
pub struct OptionsHandler(HandlerFn);

// Method enum that wraps all HTTP method handlers
pub enum Handler {
    Get(GetHandler),
    Post(PostHandler),
    Put(PutHandler),
    Delete(DeleteHandler),
    Patch(PatchHandler),
    Head(HeadHandler),
    Options(OptionsHandler),
}

// Constructor functions for HTTP method handlers
pub fn get<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Get(GetHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn post<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Post(PostHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn put<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Put(PutHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn delete<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Delete(DeleteHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn patch<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Patch(PatchHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn head<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Head(HeadHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub fn options<F, Fut>(handler: F) -> Handler
where
    F: Fn(Request<hyper::body::Incoming>) -> Fut + Send + Sync + 'static,
    Fut: Future<Output = Result<Response<String>>> + Send + 'static,
{
    Handler::Options(OptionsHandler(Box::new(move |req| {
        Routing::from_future(handler(req))
    })))
}

pub struct MethodRouter {
    handlers: Vec<Handler>,
}

impl MethodRouter {
    pub fn new() -> Self {
        Self {
            handlers: Vec::new(),
        }
    }

    pub fn route(&mut self, handler: Handler) {
        self.handlers.push(handler);
    }
}

impl Router for MethodRouter {
    fn ready(&mut self, _cx: &mut std::task::Context<'_>) -> std::task::Poll<Result<()>> {
        std::task::Poll::Ready(Ok(()))
    }

    fn handle(&self, request: Request<hyper::body::Incoming>) -> Routing {
        for handler in &self.handlers {
            match handler {
                Handler::Get(GetHandler(handler_fn)) => {
                    if request.method() == http::Method::GET {
                        return handler_fn(request);
                    }
                }
                Handler::Post(PostHandler(handler_fn)) => {
                    if request.method() == http::Method::POST {
                        return handler_fn(request);
                    }
                }
                Handler::Put(PutHandler(handler_fn)) => {
                    if request.method() == http::Method::PUT {
                        return handler_fn(request);
                    }
                }
                Handler::Delete(DeleteHandler(handler_fn)) => {
                    if request.method() == http::Method::DELETE {
                        return handler_fn(request);
                    }
                }
                Handler::Patch(PatchHandler(handler_fn)) => {
                    if request.method() == http::Method::PATCH {
                        return handler_fn(request);
                    }
                }
                Handler::Head(HeadHandler(handler_fn)) => {
                    if request.method() == http::Method::HEAD {
                        return handler_fn(request);
                    }
                }
                Handler::Options(OptionsHandler(handler_fn)) => {
                    if request.method() == http::Method::OPTIONS {
                        return handler_fn(request);
                    }
                }
            }
        }

        // Return 404 if no handler matches
        Routing::from_future(async {
            Ok(Response::builder()
                .status(StatusCode::NOT_FOUND)
                .body("Not Found".to_string())
                .unwrap())
        })
    }

    fn can_handle(&self, method: http::Method, _path: &str) -> bool {
        self.handlers.iter().any(|handler| match handler {
            Handler::Get(_) => method == http::Method::GET,
            Handler::Post(_) => method == http::Method::POST,
            Handler::Put(_) => method == http::Method::PUT,
            Handler::Delete(_) => method == http::Method::DELETE,
            Handler::Patch(_) => method == http::Method::PATCH,
            Handler::Head(_) => method == http::Method::HEAD,
            Handler::Options(_) => method == http::Method::OPTIONS,
        })
    }
}
