#![feature(trait_alias)]
pub use list::List;
pub mod list {
    use chrono as time;
    use rng::{self, Random, Range};
    use std::{
        marker::PhantomData,
        ptr::{self, NonNull},
        sync::atomic::{AtomicPtr, AtomicUsize, Ordering::*},
    };
    // Pack ptr and mark bit into single atomic for efficient CAS
    struct AtomicMarkableReference<T> {
        val: AtomicUsize,
        _marker: PhantomData<*mut T>,
    }

    impl<T> AtomicMarkableReference<T> {
        fn new(ptr: *mut T) -> Self {
            Self {
                val: AtomicUsize::new(ptr as usize & !1),
                _marker: PhantomData,
            }
        }

        fn set(&self, ptr: *mut T, mark: bool) {
            let val = (ptr as usize & !1) | (mark as usize);
            self.val.store(val, Release);
        }

        fn get(&self) -> (*mut T, bool) {
            let val = self.val.load(Acquire);
            ((val & !1) as *mut T, val & 1 == 1)
        }

        fn cas(&self, old_ptr: *mut T, new_ptr: *mut T, old_mark: bool, new_mark: bool) -> bool {
            let old_val = (old_ptr as usize & !1) | (old_mark as usize);
            let new_val = (new_ptr as usize & !1) | (new_mark as usize);
            self.val
                .compare_exchange(old_val, new_val, AcqRel, Acquire)
                .is_ok()
        }
    }

    #[test]
    fn test_basic_operations() {
        rt::block_on(async {
            let list = List::new();

            // Test insert
            assert!(list.insert(1).await);
            assert!(list.insert(2).await);
            assert!(list.insert(3).await);

            // Test contains
            assert!(list.contains(&1).await);
            assert!(list.contains(&2).await);
            assert!(list.contains(&3).await);

            // Test remove
            assert!(list.remove(&2).await);
            assert!(!list.contains(&2).await);
        });
    }

    struct Node<T> {
        value: T,
        next: Vec<AtomicMarkableReference<Node<T>>>,
    }

    pub struct List<T> {
        head: NonNull<Node<T>>,
        max_level: usize,
    }

    impl<T: Ord> List<T> {
        pub fn new() -> Self {
            // Create head node with maximum height
            let head = Box::new(Node {
                value: unsafe { std::mem::zeroed() }, // Head node value
                next: (0..32)
                    .map(|_| AtomicMarkableReference::new(ptr::null_mut()))
                    .collect(),
            });

            // CRITICAL FIX: Initialize with valid pointer
            let head_ptr = Box::into_raw(head);

            Self {
                head: unsafe { NonNull::new_unchecked(head_ptr) },
                max_level: 32,
            }
        }

        pub async fn insert(&self, value: T) -> bool {
            let mut preds = vec![ptr::null_mut(); self.max_level];
            let mut succs = vec![ptr::null_mut(); self.max_level];
            let backoff = Backoff::with_step(Duration::<Millis>::from(1));

            // First check if value already exists
            {
                let ref_value = &value; // Take reference first
                loop {
                    if !self.find(ref_value, &mut preds, &mut succs).await {
                        backoff.wait().await;
                        continue;
                    }

                    if !succs[0].is_null() && unsafe { &*succs[0] }.value == *ref_value {
                        return false;
                    }
                    break;
                }
            }

            // Generate random level and create node
            let level = rng::rng()
                .await
                .map(|x| x.sample(&Range::new(0..self.max_level)))
                .unwrap_or_default();

            let node = Box::new(Node {
                value, // Move value only once when creating node
                next: (0..=level)
                    .map(|i| AtomicMarkableReference::new(succs[i]))
                    .collect(),
            });
            let node_ptr = Box::into_raw(node);

            loop {
                if !unsafe { &*preds[0] }.next[0].cas(succs[0], node_ptr, false, false) {
                    unsafe { drop(Box::from_raw(node_ptr)) };
                    backoff.wait().await;
                    return Box::pin(self.insert(unsafe { Box::from_raw(node_ptr).value })).await;
                }

                for i in 1..=level {
                    loop {
                        let pred = preds[i];
                        let succ = succs[i];

                        if unsafe { &*node_ptr }.next[i].cas(succ, succ, false, false) {
                            break;
                        }

                        // Use reference here since value is now owned by node
                        self.find(unsafe { &(*node_ptr).value }, &mut preds, &mut succs)
                            .await;
                    }
                }

                return true;
            }
        }

        // Add validation for find operation
        async fn find(
            &self,
            value: &T,
            preds: &mut Vec<*mut Node<T>>,
            succs: &mut Vec<*mut Node<T>>,
        ) -> bool {
            // Start from head node
            let mut pred = self.head.as_ptr();

            // Traverse from top level down
            for level in (0..self.max_level).rev() {
                let mut curr = unsafe { &*pred }.next[level].get().0;

                loop {
                    if curr.is_null() {
                        break;
                    }

                    let (succ, marked) = unsafe { &*curr }.next[level].get();

                    // Skip marked (deleted) nodes
                    if marked {
                        // Try to unlink
                        if !unsafe { &*pred }.next[level].cas(curr, succ, false, false) {
                            return false; // CAS failed, retry find
                        }
                        curr = succ;
                        continue;
                    }

                    if unsafe { &*curr }.value >= *value {
                        break;
                    }

                    pred = curr;
                    curr = succ;
                }

                preds[level] = pred;
                succs[level] = curr;
            }

            true
        }

        pub async fn remove(&self, value: &T) -> bool {
            let mut preds = vec![ptr::null_mut(); self.max_level];
            let mut succs = vec![ptr::null_mut(); self.max_level];
            let backoff = Backoff::with_step(Duration::<Millis>::from(1));

            loop {
                if !self.find(value, &mut preds, &mut succs).await {
                    backoff.wait().await;
                    continue;
                }

                let node = succs[0];
                if node.is_null() || unsafe { &*node }.value != *value {
                    return false;
                }

                for level in (1..unsafe { &*node }.next.len()).rev() {
                    loop {
                        let (succ, mark) = unsafe { &*node }.next[level].get();
                        if mark {
                            break;
                        }
                        if unsafe { &*node }.next[level].cas(succ, succ, false, true) {
                            break;
                        }
                    }
                }

                loop {
                    let (succ, mark) = unsafe { &*node }.next[0].get();
                    if mark {
                        return false;
                    }
                    if unsafe { &*node }.next[0].cas(succ, succ, false, true) {
                        self.find(value, &mut preds, &mut succs);
                        return true;
                    }
                }
            }
        }

        pub async fn contains(&self, value: &T) -> bool {
            let mut pred = self.head.as_ptr();
            let mut curr = ptr::null_mut();

            for level in (0..self.max_level).rev() {
                curr = unsafe { &*pred }.next[level].get().0;

                loop {
                    if curr.is_null() {
                        break;
                    }

                    let (next, marked) = unsafe { &*curr }.next[level].get();
                    if marked {
                        curr = next;
                        continue;
                    }

                    if unsafe { &*curr }.value < *value {
                        pred = curr;
                        curr = next;
                    } else {
                        break;
                    }
                }
            }

            !curr.is_null() && unsafe { &*curr }.value == *value
        }
        pub fn len(&self) -> usize {
            let mut len = 0;
            let mut node = self.head.as_ptr();
            while !node.is_null() {
                let (next, marked) = unsafe { &*node }.next[0].get();
                if !marked {
                    len += 1;
                }
                node = next;
            }
            len
        }

        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        pub async fn get(&self, value: &T) -> Option<&T> {
            if self.contains(value).await {
                let mut node = self.head.as_ptr();
                while !node.is_null() {
                    let (next, marked) = unsafe { &*node }.next[0].get();
                    if !marked && unsafe { &*node }.value == *value {
                        return Some(&unsafe { &*node }.value);
                    }
                    node = next;
                }
            }
            None
        }

        pub fn first(&self) -> Option<&T> {
            let mut node = self.head.as_ptr();
            while !node.is_null() {
                let (next, marked) = unsafe { &*node }.next[0].get();
                if !marked {
                    return Some(&unsafe { &*node }.value);
                }
                node = next;
            }
            None
        }

        pub fn last(&self) -> Option<&T> {
            let mut last = None;
            let mut node = self.head.as_ptr();
            while !node.is_null() {
                let (next, marked) = unsafe { &*node }.next[0].get();
                if !marked {
                    last = Some(&unsafe { &*node }.value);
                }
                node = next;
            }
            last
        }
        pub async fn remove_first(&self) -> Option<T> {
            let mut pred = self.head.as_ptr();
            let mut curr = unsafe { &*pred }.next[0].get().0;

            while !curr.is_null() {
                let node = unsafe { &*curr };
                let (next, marked) = node.next[0].get();

                if !marked {
                    // Try to mark for deletion
                    if node.next[0].cas(next, next, false, true) {
                        // Help physical deletion
                        let mut preds = vec![ptr::null_mut(); self.max_level];
                        let mut succs = vec![ptr::null_mut(); self.max_level];
                        self.find(&node.value, &mut preds, &mut succs).await;

                        // Return the value
                        return Some(unsafe { Box::from_raw(curr) }.value);
                    }
                }
                curr = next;
            }
            None
        }

        pub async fn remove_last(&self) -> Option<T> {
            let mut pred = self.head.as_ptr();
            let mut curr = unsafe { &*pred }.next[0].get().0;
            let mut last_valid = None;
            let mut last_valid_ptr = ptr::null_mut();

            // Find the last non-marked node
            while !curr.is_null() {
                let node = unsafe { &*curr };
                let (next, marked) = node.next[0].get();

                if !marked {
                    last_valid = Some(&node.value);
                    last_valid_ptr = curr;
                }
                curr = next;
            }

            // If found, try to remove it
            if let Some(value) = last_valid {
                let node = unsafe { &*last_valid_ptr };
                let (next, marked) = node.next[0].get();

                if !marked && node.next[0].cas(next, next, false, true) {
                    // Help physical deletion
                    let mut preds = vec![ptr::null_mut(); self.max_level];
                    let mut succs = vec![ptr::null_mut(); self.max_level];
                    self.find(value, &mut preds, &mut succs).await;

                    // Return the value
                    return Some(unsafe { Box::from_raw(last_valid_ptr) }.value);
                }
            }
            None
        }

        pub async fn remove_at(&self, index: usize) -> Option<T> {
            let mut current_index = 0;
            let mut pred = self.head.as_ptr();
            let mut curr = unsafe { &*pred }.next[0].get().0;

            while !curr.is_null() {
                let node = unsafe { &*curr };
                let (next, marked) = node.next[0].get();

                if !marked {
                    if current_index == index {
                        if node.next[0].cas(next, next, false, true) {
                            // Help physical deletion
                            let mut preds = vec![ptr::null_mut(); self.max_level];
                            let mut succs = vec![ptr::null_mut(); self.max_level];
                            self.find(&node.value, &mut preds, &mut succs).await;

                            return Some(unsafe { Box::from_raw(curr) }.value);
                        }
                        return None;
                    }
                    current_index += 1;
                }
                curr = next;
            }
            None
        }

        pub async fn get_at(&self, index: usize) -> Option<&T> {
            let mut current_index = 0;
            let mut pred = self.head.as_ptr();
            let mut curr = unsafe { &*pred }.next[0].get().0;

            while !curr.is_null() {
                let node = unsafe { &*curr };
                let (next, marked) = node.next[0].get();

                if !marked {
                    if current_index == index {
                        return Some(&node.value);
                    }
                    current_index += 1;
                }
                curr = next;
            }
            None
        }
    }

    // Safety: List is safe to send between threads because all shared state uses atomic operations
    unsafe impl<T: Send> Send for List<T> {}
    unsafe impl<T: Sync> Sync for List<T> {}

    // Safety: Node is safe to send between threads
    unsafe impl<T: Send> Send for Node<T> {}
    unsafe impl<T: Sync> Sync for Node<T> {}

    // Safety: AtomicMarkableReference is safe to send and share between threads
    unsafe impl<T: Send> Send for AtomicMarkableReference<T> {}
    unsafe impl<T: Sync> Sync for AtomicMarkableReference<T> {}

    pub struct Iter<'a, T> {
        curr: *mut Node<T>,
        _marker: PhantomData<&'a T>,
    }

    impl<T: Ord> List<T> {
        pub fn iter(&self) -> Iter<'_, T> {
            // Skip sentinel head node
            let first = unsafe { &*self.head.as_ptr() }.next[0].get().0;
            Iter {
                curr: first,
                _marker: PhantomData,
            }
        }
    }

    impl<'a, T> Iterator for Iter<'a, T> {
        type Item = &'a T;

        fn next(&mut self) -> Option<Self::Item> {
            while !self.curr.is_null() {
                // Get current node
                let current = unsafe { &*self.curr };

                // Load next node and advance
                let (next, marked) = current.next[0].get();
                self.curr = next;

                // Return value if node is not marked as deleted
                if !marked {
                    return Some(&current.value);
                }
            }
            None
        }
    }

    // Safety: T must be Send + Sync
    unsafe impl<'a, T: Send> Send for Iter<'a, T> {}
    unsafe impl<'a, T: Sync> Sync for Iter<'a, T> {}

    impl<T> Drop for List<T> {
        fn drop(&mut self) {
            // Start from head
            let mut current = self.head.as_ptr();

            // Free all nodes including sentinel head
            while !current.is_null() {
                // Get next node before freeing current
                let next = unsafe { &*current }.next[0].get().0;

                // Convert raw pointer back to Box and drop it
                unsafe {
                    drop(Box::from_raw(current));
                }

                current = next;
            }
        }
    }
}
pub use map::{Key, Map};
mod map {
    use std::{fmt, ptr};

    use super::{List, list::Iter};

    pub trait Key = PartialEq + PartialOrd + Ord + Clone + fmt::Debug;

    #[derive(Clone)]
    pub struct KeyValue<K: Key, V>(K, Option<V>);

    impl<K: Key, V> PartialEq for KeyValue<K, V> {
        fn eq(&self, other: &Self) -> bool {
            self.0 == other.0
        }
    }

    impl<K: Key, V> PartialOrd for KeyValue<K, V> {
        fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
            self.0.partial_cmp(&other.0)
        }
    }

    impl<K: Key, V> Ord for KeyValue<K, V> {
        fn cmp(&self, other: &Self) -> std::cmp::Ordering {
            self.0.cmp(&other.0)
        }
    }

    impl<K: Key, V> Eq for KeyValue<K, V> {}

    pub struct Map<K: Key, V> {
        list: List<KeyValue<K, V>>,
    }

    unsafe impl<K: Key + Send, V: Send> Send for Map<K, V> {}
    unsafe impl<K: Key + Sync, V: Sync> Sync for Map<K, V> {}

    impl<K: Key, V> Default for Map<K, V> {
        fn default() -> Self {
            Self { list: List::new() }
        }
    }

    impl<K: Key, V> Map<K, V> {
        pub async fn get(&self, key: &K) -> Option<&V> {
            if let Some(kv) = self.list.get(&KeyValue(key.clone(), None)).await {
                kv.1.as_ref()
            } else {
                None
            }
        }
        pub async fn insert(&self, key: K, value: V) -> Option<V> {
            // First check if key exists
            if self.list.contains(&KeyValue(key.clone(), None)).await {
                // Key exists, get old value before removing
                let old_value = if let Some(kv) = self.list.get(&KeyValue(key.clone(), None)).await
                {
                    kv.1.as_ref().map(|v| unsafe { ptr::read(v) })
                } else {
                    None
                };

                // Remove old key-value pair
                self.list.remove(&KeyValue(key.clone(), None)).await;

                // Insert new value
                self.list.insert(KeyValue(key, Some(value))).await;

                old_value
            } else {
                // Key doesn't exist, simple insert
                self.list.insert(KeyValue(key, Some(value))).await;
                None
            }
        }

        pub async fn remove(&self, key: &K) -> Option<V> {
            if let Some(kv) = self.list.get(&KeyValue(key.clone(), None)).await {
                if let Some(value) = &kv.1 {
                    let value = unsafe { ptr::read(value) };
                    if self.list.remove(&KeyValue(key.clone(), None)).await {
                        return Some(value);
                    }
                }
            }
            None
        }

        pub fn first(&self) -> Option<(&K, &V)> {
            self.list
                .first()
                .and_then(|kv| kv.1.as_ref().map(|v| (&kv.0, v)))
        }

        pub fn last(&self) -> Option<(&K, &V)> {
            self.list.last().map(|kv| (&kv.0, kv.1.as_ref().unwrap()))
        }

        pub fn first_key(&self) -> Option<&K> {
            self.first().map(|(k, _)| k)
        }

        pub fn last_key(&self) -> Option<&K> {
            self.last().map(|(k, _)| k)
        }

        pub fn first_value(&self) -> Option<&V> {
            self.first().map(|(_, v)| v)
        }

        pub fn last_value(&self) -> Option<&V> {
            self.last().map(|(_, v)| v)
        }

        pub async fn remove_first(&self) -> Option<(K, V)> {
            if let Some(KeyValue(k, Some(v))) = self.list.remove_first().await {
                Some((k, v))
            } else {
                None
            }
        }

        pub async fn remove_last(&self) -> Option<(K, V)> {
            if let Some(KeyValue(k, Some(v))) = self.list.remove_last().await {
                Some((k, v))
            } else {
                None
            }
        }

        pub async fn remove_first_value(&self) -> Option<V> {
            self.remove_first().await.map(|(_, v)| v)
        }

        pub async fn remove_last_value(&self) -> Option<V> {
            self.remove_last().await.map(|(_, v)| v)
        }

        pub async fn remove_first_key(&self) -> Option<K> {
            self.remove_first().await.map(|(k, _)| k)
        }

        pub async fn remove_last_key(&self) -> Option<K> {
            self.remove_last().await.map(|(k, _)| k)
        }

        pub async fn contains_key(&self, key: &K) -> bool {
            self.list.contains(&KeyValue(key.clone(), None)).await
        }

        pub fn len(&self) -> usize {
            self.list.len()
        }

        pub fn is_empty(&self) -> bool {
            self.list.is_empty()
        }

        pub async fn get_at(&self, index: usize) -> Option<(&K, &V)> {
            self.list
                .get_at(index)
                .await
                .map(|kv| (&kv.0, kv.1.as_ref().unwrap()))
        }

        pub async fn remove_at(&self, index: usize) -> Option<(K, V)> {
            if let Some(KeyValue(k, Some(v))) = self.list.remove_at(index).await {
                Some((k, v))
            } else {
                None
            }
        }

        pub fn iter(&self) -> impl Iterator<Item = (&K, &V)> {
            self.list
                .iter()
                .filter_map(|kv| kv.1.as_ref().map(|v| (&kv.0, v)))
        }
    }
}
