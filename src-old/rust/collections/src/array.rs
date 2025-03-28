use std::marker::{PhantomData, PhantomPinned};
use std::mem::{self, MaybeUninit, transmute};
use std::ops::{Deref, DerefMut, Index, IndexMut};
use std::ptr::{self, NonNull};
use std::slice;

pub struct Array<T, const L: usize> {
    pub(crate) data: [MaybeUninit<T>; L],
    len: usize,
    phantom_pinned: PhantomPinned,
}
impl<T: std::fmt::Debug, const N: usize> std::fmt::Debug for Array<T, N> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Check if alternate formatting is requested
        if f.alternate() {
            // Detailed view with metadata
            f.debug_struct("Array")
                .field("capacity", &N)
                .field("len", &self.len)
                .field("data", &DebugArray(self))
                .finish()
        } else {
            // Compact view just showing elements
            f.debug_list().entries(self.iter()).finish()
        }
    }
}

// Helper struct for custom array debug formatting
struct DebugArray<'a, T: std::fmt::Debug, const N: usize>(&'a Array<T, N>);

impl<'a, T: std::fmt::Debug, const N: usize> std::fmt::Debug for DebugArray<'a, T, N> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let array = self.0;

        if array.len() == 0 {
            write!(f, "[]")?;
            return Ok(());
        }

        writeln!(f, "[")?;

        // Print each element with index
        for (i, item) in array.iter().enumerate() {
            write!(f, "    {i:>3}: {item:?}")?;
            if i < array.len() - 1 {
                writeln!(f, ",")?;
            } else {
                writeln!(f)?;
            }
        }

        // If there's unused capacity, indicate it
        if array.len() < N {
            writeln!(f, "    ... {} slots available", N - array.len())?;
        }

        write!(f, "]")
    }
}
impl<T, const L: usize> Array<T, L> {
    #[inline]
    pub const fn new() -> Self {
        Self {
            phantom_pinned: PhantomPinned,
            data: unsafe { MaybeUninit::uninit().assume_init() },
            len: 0,
        }
    }

    pub const fn len(&self) -> usize {
        self.len
    }

    pub const fn capacity(&self) -> usize {
        L
    }

    pub const fn is_empty(&self) -> bool {
        self.len == 0
    }

    pub const fn is_full(&self) -> bool {
        self.len == L
    }

    #[inline]
    pub fn push(&mut self, value: T) -> Result<(), T> {
        if self.len >= L {
            return Err(value);
        }
        unsafe {
            self.data[self.len].write(value);
        }
        self.len += 1;
        Ok(())
    }

    #[inline]
    pub fn try_push(&mut self, value: T) -> bool {
        match self.push(value) {
            Ok(_) => true,
            Err(_) => false,
        }
    }

    #[inline]
    pub fn pop(&mut self) -> Option<T> {
        if self.len == 0 {
            None
        } else {
            self.len -= 1;
            Some(unsafe { self.data[self.len].assume_init_read() })
        }
    }

    pub fn clear(&mut self) {
        while self.pop().is_some() {}
    }

    pub fn as_slice(&self) -> &[T] {
        self
    }

    pub fn as_mut_slice(&mut self) -> &mut [T] {
        self
    }

    pub fn iter(&self) -> Iter<'_, T, L> {
        Iter {
            data: &self.data[..self.len],
            index: 0,
            _phantom: PhantomData,
        }
    }

    pub fn iter_mut(&mut self) -> IterMut<'_, T, L> {
        IterMut {
            data: &mut self.data[..self.len],
            index: 0,
            _phantom: PhantomData,
        }
    }

    // New safe methods
    pub fn get(&self, index: usize) -> Option<&T> {
        if index < self.len {
            Some(unsafe { &*self.data[index].as_ptr() })
        } else {
            None
        }
    }

    pub fn get_mut(&mut self, index: usize) -> Option<&mut T> {
        if index < self.len {
            Some(unsafe { &mut *self.data[index].as_mut_ptr() })
        } else {
            None
        }
    }

    pub fn swap_remove(&mut self, index: usize) -> Option<T> {
        if index >= self.len {
            None
        } else {
            self.len -= 1;
            if index != self.len {
                self.data.swap(index, self.len);
            }
            Some(unsafe { self.data[self.len].assume_init_read() })
        }
    }
}

impl<T, const L: usize> Drop for Array<T, L> {
    fn drop(&mut self) {
        unsafe {
            ptr::drop_in_place(ptr::slice_from_raw_parts_mut(
                self.data.as_mut_ptr() as *mut T,
                self.len,
            ));
        }
    }
}

impl<T, const L: usize> Deref for Array<T, L> {
    type Target = [T];

    fn deref(&self) -> &[T] {
        unsafe { slice::from_raw_parts(self.data.as_ptr() as *const T, self.len) }
    }
}

impl<T, const L: usize> DerefMut for Array<T, L> {
    fn deref_mut(&mut self) -> &mut [T] {
        unsafe { slice::from_raw_parts_mut(self.data.as_mut_ptr() as *mut T, self.len) }
    }
}

impl<T, const L: usize> Index<usize> for Array<T, L> {
    type Output = T;

    fn index(&self, index: usize) -> &Self::Output {
        if index >= self.len {
            panic!(
                "index out of bounds: the len is {} but the index is {}",
                self.len, index
            );
        }
        unsafe { &*self.data[index].as_ptr() }
    }
}

impl<T, const L: usize> IndexMut<usize> for Array<T, L> {
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        if index >= self.len {
            panic!(
                "index out of bounds: the len is {} but the index is {}",
                self.len, index
            );
        }
        unsafe { &mut *self.data[index].as_mut_ptr() }
    }
}

pub struct Iter<'a, T, const L: usize> {
    data: &'a [MaybeUninit<T>],
    index: usize,
    _phantom: PhantomData<&'a T>,
}

pub struct IterMut<'a, T, const L: usize> {
    data: &'a mut [MaybeUninit<T>],
    index: usize,
    _phantom: PhantomData<&'a mut T>,
}

impl<'a, T, const L: usize> Iterator for Iter<'a, T, L> {
    type Item = &'a T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.index >= self.data.len() {
            None
        } else {
            let item = unsafe { &*self.data[self.index].as_ptr() };
            self.index += 1;
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let remaining = self.data.len() - self.index;
        (remaining, Some(remaining))
    }
}

impl<'a, T, const L: usize> Iterator for IterMut<'a, T, L> {
    type Item = &'a mut T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.index >= self.data.len() {
            None
        } else {
            let item = unsafe { &mut *self.data[self.index].as_mut_ptr() };
            self.index += 1;
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let remaining = self.data.len() - self.index;
        (remaining, Some(remaining))
    }
}

impl<'a, T, const L: usize> DoubleEndedIterator for Iter<'a, T, L> {
    fn next_back(&mut self) -> Option<Self::Item> {
        if self.index >= self.data.len() {
            None
        } else {
            let item = unsafe { &*self.data[self.data.len() - 1].as_ptr() };
            self.data = &self.data[..self.data.len() - 1];
            Some(item)
        }
    }
}

impl<T, const L: usize> DoubleEndedIterator for IterMut<'_, T, L> {
    fn next_back(&mut self) -> Option<Self::Item> {
        if self.index >= self.data.len() {
            None
        } else {
            let new_len = self.data.len() - 1;
            let item = unsafe { &mut *self.data[new_len].as_mut_ptr() };
            self.data = unsafe { transmute(&mut self.data[..new_len]) };
            Some(item)
        }
    }
}

impl<'a, T, const L: usize> ExactSizeIterator for Iter<'a, T, L> {}
impl<'a, T, const L: usize> ExactSizeIterator for IterMut<'a, T, L> {}

impl<T, const L: usize> IntoIterator for Array<T, L> {
    type Item = T;
    type IntoIter = IntoIter<T, L>;

    fn into_iter(self) -> IntoIter<T, L> {
        IntoIter {
            array: self,
            index: 0,
        }
    }
}

pub struct IntoIter<T, const L: usize> {
    array: Array<T, L>,
    index: usize,
}

impl<T, const L: usize> Iterator for IntoIter<T, L> {
    type Item = T;

    fn next(&mut self) -> Option<Self::Item> {
        if self.index >= self.array.len {
            None
        } else {
            let item = unsafe { self.array.data[self.index].assume_init_read() };
            self.index += 1;
            Some(item)
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let remaining = self.array.len - self.index;
        (remaining, Some(remaining))
    }
}

impl<T, const L: usize> Drop for IntoIter<T, L> {
    fn drop(&mut self) {
        for i in self.index..self.array.len {
            unsafe {
                ptr::drop_in_place(self.array.data[i].as_mut_ptr());
            }
        }
    }
}

impl<T: Clone, const L: usize> Clone for Array<T, L> {
    fn clone(&self) -> Self {
        let mut new = Self::new();
        new.len = self.len;
        for i in 0..self.len {
            unsafe {
                new.data[i] = MaybeUninit::new((*self.data[i].as_ptr()).clone());
            }
        }
        new
    }
}

impl<T: PartialEq, const L: usize> PartialEq for Array<T, L> {
    fn eq(&self, other: &Self) -> bool {
        if self.len != other.len {
            return false;
        }
        for i in 0..self.len {
            unsafe {
                if *self.data[i].as_ptr() != *other.data[i].as_ptr() {
                    return false;
                }
            }
        }
        true
    }
}

impl<T: Eq, const L: usize> Eq for Array<T, L> {}

impl<T: PartialOrd, const L: usize> PartialOrd for Array<T, L> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        let len = self.len.min(other.len);
        for i in 0..len {
            unsafe {
                match (*self.data[i].as_ptr()).partial_cmp(&*other.data[i].as_ptr()) {
                    Some(std::cmp::Ordering::Equal) => continue,
                    not_eq => return not_eq,
                }
            }
        }
        self.len.partial_cmp(&other.len)
    }
}

impl<T: Ord, const L: usize> Ord for Array<T, L> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        let len = self.len.min(other.len);
        for i in 0..len {
            unsafe {
                match (*self.data[i].as_ptr()).cmp(&*other.data[i].as_ptr()) {
                    std::cmp::Ordering::Equal => continue,
                    not_eq => return not_eq,
                }
            }
        }
        self.len.cmp(&other.len)
    }
}

impl<T: std::hash::Hash, const L: usize> std::hash::Hash for Array<T, L> {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        self.len.hash(state);
        for i in 0..self.len {
            unsafe {
                (*self.data[i].as_ptr()).hash(state);
            }
        }
    }
}

impl<T, const L: usize> Default for Array<T, L> {
    fn default() -> Self {
        Self::new()
    }
}

impl<T, const L: usize> Extend<T> for Array<T, L> {
    fn extend<I: IntoIterator<Item = T>>(&mut self, iter: I) {
        for item in iter {
            if self.len >= L {
                break;
            }
            unsafe {
                self.data[self.len].write(item);
            }
            self.len += 1;
        }
    }
}

impl<T, const L: usize> FromIterator<T> for Array<T, L> {
    fn from_iter<I: IntoIterator<Item = T>>(iter: I) -> Self {
        let mut array = Self::new();
        array.extend(iter);
        array
    }
}

// Safety implementations
unsafe impl<T: Send, const L: usize> Send for Array<T, L> {}
unsafe impl<T: Sync, const L: usize> Sync for Array<T, L> {}

#[macro_export]
macro_rules! array {
    () => ({
        base::collections::array::Array::<_, 0>::new()
    });
    ($elem:expr) => ({
        let mut a = base::collections::array::Array::<_, 1>::new();
        a.push($elem).unwrap();
        a
    });
    ($($x:expr),+ $(,)?) => ({
        let mut a = Array::<_, {<[()]>::len(&[$(base::replace_expr!($x, ())),*])}>::new();
        $(
            a.push($x);
        )*
        a
    });
}

#[macro_export]
#[doc(hidden)]
macro_rules! replace_expr {
    ($_t:tt, $sub:expr) => {
        $sub
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push_pop() {
        let mut array = Array::<i32, 3>::new();
        assert!(array.push(1).is_ok());
        assert!(array.push(2).is_ok());
        assert!(array.push(3).is_ok());
        assert!(array.push(4).is_err());
        assert_eq!(array.pop(), Some(3));
        assert_eq!(array.pop(), Some(2));
        assert_eq!(array.pop(), Some(1));
        assert_eq!(array.pop(), None);
    }

    #[test]
    fn test_iter() {
        let mut array = Array::<i32, 3>::new();
        array.push(1).unwrap();
        array.push(2).unwrap();
        array.push(3).unwrap();
        let mut iter = array.iter();
        assert_eq!(iter.next(), Some(&1));
        assert_eq!(iter.next(), Some(&2));
        assert_eq!(iter.next(), Some(&3));
        assert_eq!(iter.next(), None);
    }

    #[test]
    fn test_into_iter() {
        let mut array = Array::<i32, 3>::new();
        array.push(1).unwrap();
        array.push(2).unwrap();
        array.push(3).unwrap();
        let mut iter = array.into_iter();
        assert_eq!(iter.next(), Some(1));
        assert_eq!(iter.next(), Some(2));
        assert_eq!(iter.next(), Some(3));
        assert_eq!(iter.next(), None);
    }

    #[test]
    fn test_macro() {
        let array = array![1, 2, 3];
        assert_eq!(array.len(), 3);
        assert_eq!(array[0], 1);
        assert_eq!(array[1], 2);
        assert_eq!(array[2], 3);
    }
}
