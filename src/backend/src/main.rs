use rand::Rng;
use std::{
    marker::PhantomData,
    net::{SocketAddr, ToSocketAddrs},
    pin::Pin,
    task::{Context, Poll},
};
use tower::{Layer, Service};

use axum::{
    Extension, Router,
    extract::{Path, Request, State},
    http::StatusCode,
    middleware::{self, Next},
    response::Response,
    routing::{any, delete, get, patch, post},
};

pub type Result<T, E = anyhow::Error> = anyhow::Result<T, E>;

#[derive(Clone)]
pub struct Tenant(String);

pub struct AppState {}

pub struct Org {
    pub primary: u128,
    pub visual: String,
    pub name: String,
}

impl Org {
    pub async fn create(create: CreateOrg) -> Result<Self> {
        let id = OrgId::random();

        Ok(todo!())
    }
}

pub struct CreateOrg {
    pub name: String,
}

pub struct UpdateOrg {
    pub name: Option<String>,
}

pub struct OrgResponse {
    pub visual: String,
    pub name: String,
}

pub struct OrgId {
    primary: u128,
    visual: String,
}

impl OrgId {
    pub fn random() -> Self {
        Self {
            primary: Self::random_primary(),
            visual: Self::random_visual(),
        }
    }

    pub fn random_primary() -> u128 {
        rand::thread_rng().random::<u128>()
    }

    pub fn random_visual() -> String {
        const WORDS: &str = include_str!("word-list");
        const NUM_WORDS: usize = 2;

        let words = WORDS.split_whitespace().collect::<Vec<_>>();
        let mut rng = rand::thread_rng();
        let mut id = String::new();
        for _ in 0..NUM_WORDS {
            id.push_str(words[rng.random_range(0..words.len())]);
            id.push('-');
        }
        id.pop();
        id
    }
}

pub async fn create_org() {}
pub async fn delete_org() {
    // Implementation for getting organizations
}
pub async fn update_org() {
    // Implementation for getting organizations
}

pub async fn get_org() -> String {
    "".to_string()
}

async fn orgs_middleware(mut request: Request, next: Next) -> Response {
    let org_visual = dbg!(request.uri().path())
        .split('/')
        .nth(2)
        .unwrap()
        .to_string();
    // request.extensions_mut().insert(Org(active_org));
    let response = next.run(request).await;
    response
}

async fn tenant_middleware(
    mut request: Request,
    next: Next,
) -> Result<Response, (StatusCode, String)> {
    let host = request
        .headers()
        .get("host")
        .ok_or((StatusCode::BAD_REQUEST, "Host header missing".to_string()))?
        .to_str()
        .unwrap();
    let tenant = host.to_string();
    dbg!(&tenant);
    request.extensions_mut().insert(Tenant(tenant));
    let response = next.run(request).await;
    Ok(response)
}

#[tokio::main]
pub async fn main() {
    // let pool = PgPoolOptions::new()
    //     .max_connections(5)
    //     .connect("postgres://postgres:password@localhost/test")
    //     .await
    //     .unwrap();
    let org_sub = Router::new()
        .route("/", patch(update_org))
        .route("/", delete(delete_org))
        .route("/", get(get_org));
    let org = Router::new()
        .nest("/org/{org_id}", org_sub)
        .layer(middleware::from_fn(orgs_middleware))
        .route("/org", post(create_org));
    let app = Router::new()
        .layer(middleware::from_fn(tenant_middleware))
        .merge(org);
    let addr = SocketAddr::from(([127, 0, 0, 1], 8080));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
