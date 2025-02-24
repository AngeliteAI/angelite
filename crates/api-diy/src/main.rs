use http::Router;

#[base::main]
async fn main() {
    http::serve(Router {}).await;
}
