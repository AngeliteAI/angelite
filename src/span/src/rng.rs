use std::cell::Cell;

pub trait Rng {
    fn random(& self) -> u128;
}

pub struct Time {
    state: Cell<Option<u128>>,
}

impl Rng for Time {
    fn random(& self) -> u128 {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u128;
        if let Some(prev) = self.state.get() {
            self.state.set(Some((prev + 1) ^ now));
            prev
        } else {
            self.state.set(Some(now));
            now
        }
    }
}