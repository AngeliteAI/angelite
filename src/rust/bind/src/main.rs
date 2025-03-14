use bind::*;
fn main() {
    bind(Config {
        workspace: "/Users/solmidnight/work/angelite".into(),
        source: Library {
            lang: Language::Zig,
            dir: "/Users/solmidnight/work/angelite/src/zig/base/".into(),
        },
        deps: vec![],
        target: Library {
            lang: Language::Rust,
            dir: "/Users/solmidnight/work/angelite/src/rust/base/".into(),
        },
    });
}
