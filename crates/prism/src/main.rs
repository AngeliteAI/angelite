pub enum Unit {

}

pub enum UnitMessage {
    Move(IVec2)
}

pub enum Terrain {

}

pub struct Recon {
    nearby_units: Arc<Fn() -> Vec<Unit>>,
}

pub struct Motor {
    current_terrain: Arc<Fn() -> Terrain>>,
}



fn main() {

}
