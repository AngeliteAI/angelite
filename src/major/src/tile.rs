pub struct Tile {
    pub(crate) ty: Type,
}
#[derive(Debug, Clone)]
pub enum Type {
    Grass,
    Dirt,
    Stone,
}
