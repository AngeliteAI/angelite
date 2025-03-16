use bind::*;
fn main() {
    bind(Config {
        source: Library {
            lang: Language::Zig,
            dir: "/Users/solmidnight/work/angelite/src/zig/math/".into(),
        },
        deps: vec![],
        target: Library {
            lang: Language::Swift,
            dir: "/Users/solmidnight/work/angelite/src/swift/gfx/".into(),
        },
    });
}
