use std::marker::PhantomData;
use std::mem::{self, MaybeUninit};
use std::ops::{Index, IndexMut};
use std::ptr::{self, NonNull};

pub struct Array<T, const L: usize> {
    data: [MaybeUninit<T>; L],
    len: usize,
}

impl<T, const L: usize> Default for Array<T, L> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T, const L: usize> Array<T, L> {
    #[inline]
    pub const fn new() -> Self {
        Self {
            // SAFETY: MaybeUninit array initialization is safe
            data: unsafe { MaybeUninit::uninit().assume_init() },
            len: 0,
        }
    }

    #[inline]
    pub fn push(&mut self, value: T) -> bool {
        if self.len < L {
            // SAFETY: len is always <= L, index is valid
            unsafe {
                self.data[self.len].write(value);
            }
            self.len += 1;
            true
        } else {
            false
        }
    }

    #[inline]
    pub fn pop(&mut self) -> Option<T> {
        if self.len > 0 {
            self.len -= 1;
            // SAFETY: len was > 0, element is initialized
            Some(unsafe { self.data[self.len].assume_init_read() })
        } else {
            None
        }
    }
}

impl<T, const L: usize> Drop for Array<T, L> {
    fn drop(&mut self) {
        while self.pop().is_some() {}
    }
}

impl<T, const L: usize> Index<usize> for Array<T, L> {
    type Output = T;

    #[inline]
    fn index(&self, index: usize) -> &Self::Output {
        assert!(index < self.len);
        // SAFETY: index < len ensures initialized value
        unsafe { &*self.data[index].as_ptr() }
    }
}

impl<T, const L: usize> IndexMut<usize> for Array<T, L> {
    #[inline]
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        assert!(index < self.len);
        // SAFETY: index < len ensures initialized value
        unsafe { &mut *self.data[index].as_mut_ptr() }
    }
}

pub struct IntoIter<T, const N: usize> {
    ptr: NonNull<T>,
    left: *const T,
    right: *const T,
    _marker: PhantomData<[T; N]>,
}

impl<T, const N: usize> Array<T, N> {
    pub fn iter(&self) -> Iter<'_, T, N> {
        // SAFETY: data pointer is valid for N elements
        unsafe {
            let ptr = self.data.as_ptr() as *const T;
            Iter {
                ptr: NonNull::new_unchecked(ptr as *mut T),
                left: ptr,
                right: ptr.add(self.len),
                _marker: PhantomData,
            }
        }
    }

    pub fn iter_mut(&mut self) -> IterMut<'_, T, N> {
        // SAFETY: data pointer is valid for N elements
        unsafe {
            let ptr = self.data.as_mut_ptr() as *mut T;
            IterMut {
                ptr: NonNull::new_unchecked(ptr),
                left: ptr,
                right: ptr.add(self.len),
                _marker: PhantomData,
            }
        }
    }
}

impl<T, const N: usize> IntoIterator for Array<T, N> {
    type Item = T;
    type IntoIter = IntoIter<T, N>;

    fn into_iter(self) -> Self::IntoIter {
        // SAFETY: data pointer is valid for N elements
        unsafe {
            let ptr = self.data.as_ptr() as *mut T;
            IntoIter {
                ptr: NonNull::new_unchecked(ptr),
                left: ptr,
                right: ptr.add(self.len),
                _marker: PhantomData,
            }
        }
    }
}

// Iterator implementations
impl<T, const N: usize> Iterator for IntoIter<T, N> {
    type Item = T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right, so pointer is valid
        unsafe {
            let item = self.left.read();
            self.left = self.left.add(1);
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = (self.right as usize - self.left as usize) / std::mem::size_of::<T>();
        (len, Some(len))
    }
}

impl<T, const N: usize> DoubleEndedIterator for IntoIter<T, N> {
    fn next_back(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right, so pointer is valid
        unsafe {
            self.right = self.right.sub(1);
            Some(self.right.read())
        }
    }
}

// Drop impl to clean up remaining elements
impl<T, const N: usize> Drop for IntoIter<T, N> {
    fn drop(&mut self) {
        // Drop any remaining elements
        while let Some(_) = self.next() {}
    }
}

pub struct Iter<'a, T, const N: usize> {
    ptr: NonNull<T>,
    left: *const T,
    right: *const T,
    _marker: PhantomData<&'a [T]>,
}

pub struct IterMut<'a, T, const N: usize> {
    ptr: NonNull<T>,
    left: *mut T,
    right: *mut T,
    _marker: PhantomData<&'a mut [T]>,
}

impl<'a, T, const N: usize> Iterator for Iter<'a, T, N> {
    type Item = &'a T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right so pointer is valid
        unsafe {
            let item = &*self.left;
            self.left = self.left.add(1);
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = (self.right as usize - self.left as usize) / std::mem::size_of::<T>();
        (len, Some(len))
    }
}

impl<'a, T, const N: usize> Iterator for IterMut<'a, T, N> {
    type Item = &'a mut T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right so pointer is valid
        unsafe {
            let item = &mut *self.left;
            self.left = self.left.add(1);
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = (self.right as usize - self.left as usize) / std::mem::size_of::<T>();
        (len, Some(len))
    }
}

impl<'a, T, const N: usize> DoubleEndedIterator for Iter<'a, T, N> {
    fn next_back(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right so pointer is valid
        unsafe {
            self.right = self.right.sub(1);
            Some(&*self.right)
        }
    }
}

impl<'a, T, const N: usize> DoubleEndedIterator for IterMut<'a, T, N> {
    fn next_back(&mut self) -> Option<Self::Item> {
        if self.left >= self.right {
            return None;
        }
        // SAFETY: left < right so pointer is valid
        unsafe {
            self.right = self.right.sub(1);
            Some(&mut *self.right)
        }
    }
}

impl<T, const N: usize> FromIterator<T> for Array<T, N> {
    fn from_iter<I: IntoIterator<Item = T>>(iter: I) -> Self {
        let mut array = Self::new();
        let mut iter = iter.into_iter();

        // Slower path: need to check bounds each time
        while let Some(value) = iter.next() {
            if !array.push(value) {
                // Array is full but iterator has more elements
                panic!("Iterator too long for array size");
            }
        }

        array
    }
}
impl<T: Clone, const N: usize> Clone for Array<T, N> {
    fn clone(&self) -> Self {
        let mut new = Self::new();
        // SAFETY: We maintain same length and initialization state
        unsafe {
            for i in 0..self.len {
                new.data[i].write((*self.data[i].as_ptr()).clone());
            }
            new.len = self.len;
        }
        new
    }
}

impl<T: PartialEq, const N: usize> PartialEq for Array<T, N> {
    fn eq(&self, other: &Self) -> bool {
        if self.len != other.len {
            return false;
        }
        // SAFETY: We only compare initialized elements up to len
        unsafe {
            for i in 0..self.len {
                if *self.data[i].as_ptr() != *other.data[i].as_ptr() {
                    return false;
                }
            }
        }
        true
    }
}

impl<T: Eq, const N: usize> Eq for Array<T, N> {}

impl<T: PartialOrd, const N: usize> PartialOrd for Array<T, N> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        let len = self.len.min(other.len);
        // SAFETY: We only compare initialized elements up to min length
        unsafe {
            for i in 0..len {
                match (*self.data[i].as_ptr()).partial_cmp(&*other.data[i].as_ptr()) {
                    Some(std::cmp::Ordering::Equal) => continue,
                    not_eq => return not_eq,
                }
            }
        }
        self.len.partial_cmp(&other.len)
    }
}

impl<T: Ord, const N: usize> Ord for Array<T, N> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        let len = self.len.min(other.len);
        // SAFETY: We only compare initialized elements up to min length
        unsafe {
            for i in 0..len {
                match (*self.data[i].as_ptr()).cmp(&*other.data[i].as_ptr()) {
                    std::cmp::Ordering::Equal => continue,
                    not_eq => return not_eq,
                }
            }
        }
        self.len.cmp(&other.len)
    }
}

impl<T: std::fmt::Debug, const N: usize> std::fmt::Debug for Array<T, N> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_list().entries(self.iter()).finish()
    }
}

impl<T: std::hash::Hash, const N: usize> std::hash::Hash for Array<T, N> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.len.hash(state);
        // SAFETY: We only hash initialized elements up to len
        unsafe {
            for i in 0..self.len {
                (*self.data[i].as_ptr()).hash(state);
            }
        }
    }
}

// Additional useful traits

unsafe impl<T: Send, const N: usize> Send for Array<T, N> {}
unsafe impl<T: Sync, const N: usize> Sync for Array<T, N> {}

impl<T, const N: usize> Extend<T> for Array<T, N> {
    fn extend<I: IntoIterator<Item = T>>(&mut self, iter: I) {
        for item in iter {
            if !self.push(item) {
                break;
            }
        }
    }
}

// Implement ExactSizeIterator for all iterator types
impl<T, const N: usize> ExactSizeIterator for IntoIter<T, N> {}
impl<'a, T, const N: usize> ExactSizeIterator for Iter<'a, T, N> {}
impl<'a, T, const N: usize> ExactSizeIterator for IterMut<'a, T, N> {}

// Implement FusedIterator for all iterator types
impl<T, const N: usize> std::iter::FusedIterator for IntoIter<T, N> {}
impl<'a, T, const N: usize> std::iter::FusedIterator for Iter<'a, T, N> {}
impl<'a, T, const N: usize> std::iter::FusedIterator for IterMut<'a, T, N> {}
