use super::array::Array;
use std::mem::{self, MaybeUninit};
use std::ops::{Deref, DerefMut, Index, IndexMut};

/// A vector backed by inline array storage that falls back to heap allocation
pub struct ArrayVec<T, const N: usize>(State<T, N>);

pub enum State<T, const N: usize> {
    Array(Array<T, N>),
    Vec(Vec<T>),
}

impl<T, const N: usize> ArrayVec<T, N> {
    /// Create a new empty ArrayVec
    pub fn new() -> Self {
        Self(State::Array(Array::new()))
    }

    /// Returns current length
    pub fn len(&self) -> usize {
        match &self.0 {
            State::Array(arr) => arr.len(),
            State::Vec(vec) => vec.len(),
        }
    }

    /// Check if empty
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Push an item, converting to Vec if array is full
    pub fn push(&mut self, value: T) {
        match &mut self.0 {
            State::Array(arr) => {
                if arr.len() < N {
                    arr.push(value);
                } else {
                    // Array is full, convert to Vec
                    let mut vec = Vec::with_capacity(N * 2);
                    for i in 0..N {
                        vec.push(unsafe { arr.data[i].assume_init_read() });
                    }
                    vec.push(value);
                    self.0 = State::Vec(vec);
                }
            }
            State::Vec(vec) => vec.push(value),
        }
    }

    /// Pop an item
    pub fn pop(&mut self) -> Option<T> {
        match &mut self.0 {
            State::Array(arr) => arr.pop(),
            State::Vec(vec) => vec.pop(),
        }
    }

    /// Clear all elements
    pub fn clear(&mut self) {
        match &mut self.0 {
            State::Array(arr) => while arr.pop().is_some() {},
            State::Vec(vec) => vec.clear(),
        }
    }
}

// Index access
impl<T, const N: usize> Index<usize> for ArrayVec<T, N> {
    type Output = T;

    fn index(&self, index: usize) -> &Self::Output {
        match &self.0 {
            State::Array(arr) => &arr[index],
            State::Vec(vec) => &vec[index],
        }
    }
}

impl<T, const N: usize> IndexMut<usize> for ArrayVec<T, N> {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        match &mut self.0 {
            State::Array(arr) => &mut arr[index],
            State::Vec(vec) => &mut vec[index],
        }
    }
}

// Iterator implementation
impl<T, const N: usize> IntoIterator for ArrayVec<T, N> {
    type Item = T;
    type IntoIter = IntoIter<T, N>;

    fn into_iter(mut self) -> Self::IntoIter {
        match std::mem::replace(&mut self.0, State::Array(Array::new())) {
            State::Array(arr) => IntoIter::Array(arr.into_iter()),
            State::Vec(vec) => IntoIter::Vec(vec.into_iter()),
        }
    }
}

pub enum IntoIter<T, const N: usize> {
    Array(super::array::IntoIter<T, N>),
    Vec(std::vec::IntoIter<T>),
}

impl<T, const N: usize> Iterator for IntoIter<T, N> {
    type Item = T;

    fn next(&mut self) -> Option<Self::Item> {
        match self {
            Self::Array(iter) => iter.next(),
            Self::Vec(iter) => iter.next(),
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        match self {
            Self::Array(iter) => iter.size_hint(),
            Self::Vec(iter) => iter.size_hint(),
        }
    }
}

// Cleanup on drop
impl<T, const N: usize> Drop for ArrayVec<T, N> {
    fn drop(&mut self) {
        self.clear();
    }
}

impl<T, const N: usize> FromIterator<T> for ArrayVec<T, N> {
    fn from_iter<I: IntoIterator<Item = T>>(iter: I) -> Self {
        let iter = iter.into_iter();

        // If we can determine size, preallocate appropriately
        let (lower, upper) = iter.size_hint();
        if let Some(upper) = upper {
            if upper <= N {
                // Known to fit in array
                let mut arr = Array::new();
                for item in iter {
                    arr.push(item);
                }
                Self(State::Array(arr))
            } else {
                // Known to need Vec
                let mut vec = Vec::with_capacity(upper);
                vec.extend(iter);
                Self(State::Vec(vec))
            }
        } else {
            // Size unknown, start with array
            let mut arr = Array::new();
            let mut iter = iter;

            // Fill array first
            while arr.len() < N {
                match iter.next() {
                    Some(item) => {
                        arr.push(item);
                    }
                    None => return Self(State::Array(arr)),
                }
            }

            // Array full, need to convert to vec
            let mut vec = Vec::with_capacity(N * 2);
            for i in 0..N {
                vec.push(unsafe { arr.data[i].assume_init_read() });
            }

            // Continue with remaining items
            vec.extend(iter);
            Self(State::Vec(vec))
        }
    }
}

// Add some additional convenience implementations

impl<T, const N: usize> Default for ArrayVec<T, N> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T: Clone, const N: usize> Clone for ArrayVec<T, N> {
    fn clone(&self) -> Self {
        match &self.0 {
            State::Array(arr) => Self(State::Array(arr.clone())),
            State::Vec(vec) => Self(State::Vec(vec.clone())),
        }
    }
}

impl<T: PartialEq, const N: usize> PartialEq for ArrayVec<T, N> {
    fn eq(&self, other: &Self) -> bool {
        if self.len() != other.len() {
            return false;
        }
        for i in 0..self.len() {
            if self[i] != other[i] {
                return false;
            }
        }
        true
    }
}

impl<T: Eq, const N: usize> Eq for ArrayVec<T, N> {}
