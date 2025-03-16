use bind::*;
fn main() {
    bind(Config {
        source: Library {
            lang: Language::Zig,
            dir: "/Users/solmidnight/work/angelite/src/zig/math/".into(),
        },
        deps: vec![],
        target: Library {
            lang: Language::Rust,
            dir: "/Users/solmidnight/work/angelite/src/rust/math/".into(),
        },
    });
}
