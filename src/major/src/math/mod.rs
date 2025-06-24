use num_traits::Zero;
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Vector<T, const N: usize>(pub [T; N]);

impl<T: Zero + Default + Copy, const N: usize> Default for Vector<T, N> {
    fn default() -> Self {
        Self([T::zero(); N])
    }
}

pub struct Quaternion<T> {
    vector: Vector<T, 3>,
    scalar: T,
}
