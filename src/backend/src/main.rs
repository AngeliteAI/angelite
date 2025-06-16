use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4, TcpStream};

use http::Response;
use span::{MethodRouter, Service, get, wrap_tokio};
use tokio::io::AsyncWriteExt;
use tokio::net::TcpListener;

#[tokio::main]
pub async fn main() {
    let tcp = TcpListener::bind(SocketAddr::V4(SocketAddrV4::new(
        Ipv4Addr::new(0, 0, 0, 0),
        80,
    )))
    .await
    .unwrap();

    loop {
        let (stream, _) = tcp.accept().await.unwrap();
        let mut methods = MethodRouter::new();
        methods.route(get(|incoming| async move {
            Ok(Response::builder()
                .status(200)
                .body("Hello, World!".into())
                .unwrap())
        }));
        let mut service = Service::make(methods);
        tokio::spawn(async move {
            service.serve(wrap_tokio(stream)).await;
        });
    }
}
