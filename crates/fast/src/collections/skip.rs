pub use list::List;
pub mod list {
    use std::{
        cmp::Ordering,
        convert::identity,
        iter, ptr,
        sync::{
            Arc,
            atomic::{AtomicBool, AtomicPtr, AtomicU64, AtomicUsize, Ordering::*},
        },
    };

    use crate::{
        prelude::Vector,
        rng::{self, Pcg, Random, random},
        sync::backoff::Backoff,
        time::{Duration, Millis},
    };

    pub struct List<T, const LEVEL: usize = 32> {
        version: Arc<AtomicU64>,
        head: Arc<AtomicPtr<Node<T>>>,
        level: Arc<AtomicUsize>,
        len: Arc<AtomicUsize>,
    }

    impl<T, const L: usize> Default for List<T, L> {
        fn default() -> Self {
            Self {
                version: Arc::new(AtomicU64::new(0)),
                head: Arc::new(AtomicPtr::new(ptr::null_mut())),
                level: Arc::new(AtomicUsize::new(0)),
                len: Arc::new(AtomicUsize::new(0)),
            }
        }
    }

    type Level = usize;

    pub async fn random_level<const MAX: usize>() -> Level {
        for i in 0..MAX {
            if random::<bool>().await.unwrap_or_default() {
                return i;
            }
        }
        return MAX;
    }

    pub struct Node<T> {
        value: T,
        version: AtomicU64,
        lock: AtomicBool,
        next: Vec<AtomicPtr<Node<T>>>,
        level: Level,
    }
    pub struct Contention;

    impl<T: PartialOrd, const L: usize> List<T, L>
    where
        [(); L + 1]: Sized,
    {
        pub fn is_empty(&self) -> bool {
            self.head.load(Acquire).is_null()
        }

        async fn try_insert(
            &self,
            node: &Arc<Node<T>>,
            update: &mut [*mut Node<T>],
            level: usize,
        ) -> Result<(), Contention> {
            let new_version = self.version.fetch_add(1, Release);

            // Update versions of affected nodes in the update path
            for level in 0..=level {
                if let Some(update_node) = unsafe { update[level].as_ref() } {
                    update_node.version.store(new_version, Release);
                }
            }

            node.version.store(new_version, Release);

            for level in 0..=level {
                let update_node = unsafe { &*update[level] };
                let next = update_node.next[level].load(Acquire);

                node.next[level].store(next, Release);

                if update_node.next[level]
                    .compare_exchange(next, Arc::into_raw(node.clone()) as *mut _, AcqRel, Acquire)
                    .is_err()
                {
                    return Err(Contention);
                }
            }

            self.len.fetch_add(1, Release);
            self.level.fetch_max(level, Release);
            Ok(())
        }

        pub async fn get(&self, value: &T) -> Option<&T> {
            let mut current = self.head.load(Acquire);

            for level in (0..=self.level.load(Acquire)).rev() {
                while let Some(next) = unsafe { (*current).next[level].load(Acquire).as_mut() } {
                    if !next.lock.load(Acquire) {
                        match next
                            .value
                            .partial_cmp(value)
                            .expect("failed to compare nodes")
                        {
                            Ordering::Less => current = next,
                            Ordering::Equal => return Some(&next.value),
                            Ordering::Greater => break,
                        }
                    }
                }
            }
            None
        }

        pub async fn insert(&self, value: T) -> Option<T> {
            let level = random_level::<L>().await;
            let node = Arc::new(Node {
                level,
                value,
                lock: false.into(),
                next: vec![].into(),
                version: 0.into(),
            });
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));
            let (prev, mut path) = match self.find_path(&node.value).await {
                Ok(path) => {
                    let prev = self.remove(&node.value).await;
                    (prev, path)
                }
                Err(path) => (None, path),
            };

            loop {
                match self.try_insert(&node, &mut path, level).await {
                    Ok(_) => return prev,
                    Err(_) => {
                        (backoff)().await;
                        continue;
                    }
                }
            }
        }

        pub async fn exists(&self, value: &T) -> bool {
            let mut current = self.head.load(Acquire);

            for level in (0..=self.level.load(Acquire)).rev() {
                while let Some(next) = unsafe { (*current).next[level].load(Acquire).as_mut() } {
                    if !next.lock.load(Acquire) {
                        match next
                            .value
                            .partial_cmp(value)
                            .expect("failed to compare nodes")
                        {
                            Ordering::Less => current = next,
                            Ordering::Equal => return true,
                            Ordering::Greater => break,
                        }
                    }
                }
            }
            false
        }

        pub async fn find_path(
            &self,
            value: &T,
        ) -> Result<[*mut Node<T>; { L + 1 }], [*mut Node<T>; { L + 1 }]> {
            let mut update = [ptr::null_mut::<Node<T>>(); { L + 1 }];
            let mut current = self.head.load(Acquire);
            let mut level = self.level.load(Acquire);

            loop {
                let curr_next = unsafe { (*current).next[level].load(Acquire) };
                if curr_next.is_null() {
                    update[level] = current;
                    if level == 0 {
                        break Err(update);
                    }
                    level -= 1;
                    continue;
                }

                let next = unsafe { &*curr_next };
                if next.lock.load(Acquire) {
                    continue;
                }

                match next
                    .value
                    .partial_cmp(value)
                    .expect("failed to compare nodes")
                {
                    Ordering::Less => current = curr_next,
                    Ordering::Equal => {
                        update[level..=next.level].fill(curr_next);
                        update[..level].fill(current);
                        break Ok(update);
                    }
                    Ordering::Greater => {
                        update[level] = current;
                        if level == 0 {
                            break Err(update);
                        }
                        level -= 1;
                    }
                }
            }
        }

        pub async fn try_remove(
            &self,
            node_ptr: *mut Node<T>,
            update: &[*mut Node<T>],
        ) -> Result<T, Contention> {
            let node = unsafe { &*node_ptr };

            // First try to acquire lock
            if !node
                .lock
                .compare_exchange(false, true, AcqRel, Acquire)
                .is_ok()
            {
                return Err(Contention);
            }

            let new_version = self.version.fetch_add(1, Release);

            // Update versions of affected nodes in the update path
            for level in 0..=node.level {
                if let Some(update_node) = unsafe { update[level].as_ref() } {
                    update_node.version.store(new_version, Release);
                }
            }

            node.version.store(new_version, Release);

            for level in 0..=node.level {
                let next = unsafe { (*node_ptr).next[level].load(Acquire) };
                if unsafe {
                    (*update[level]).next[level]
                        .compare_exchange(node_ptr, next, AcqRel, Acquire)
                        .is_err()
                } {
                    // If any level fails, unlock and return error
                    node.lock.store(false, Release);
                    return Err(Contention);
                }
            }

            self.len.fetch_sub(1, Release);
            Ok(unsafe { Box::from_raw(node_ptr).value })
        }

        pub async fn remove(&self, value: &T) -> Option<T> {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            loop {
                let update = self.find_path(value).await.ok()?;
                let node_ptr = update[0];

                // Check if we found the node
                if unsafe { (*node_ptr).value != *value } {
                    return None;
                }

                match self.try_remove(node_ptr, &update).await {
                    Ok(value) => return Some(value),
                    Err(_) => {
                        (backoff)().await;
                        continue;
                    }
                }
            }
        }
        pub fn len(&self) -> usize {
            self.len.load(Acquire)
        }

        pub fn remove_first(&self) -> Option<T> {
            let mut current = self.head.load(Acquire);
            if current.is_null() {
                return None;
            }

            let first_node = unsafe { &*current };
            for level in 0..=first_node.level {
                let next = first_node.next[level].load(Acquire);
                self.head.store(next, Release);
            }

            self.len.fetch_sub(1, Release);
            Some(unsafe { Box::from_raw(current).value })
        }

        pub fn remove_last(&self) -> Option<T> {
            let mut current = self.head.load(Acquire);
            if current.is_null() {
                return None;
            }

            let mut prev = ptr::null_mut();
            let mut level = self.level.load(Acquire);

            while level > 0 {
                while let Some(next) = unsafe { (*current).next[level].load(Acquire).as_mut() } {
                    prev = current;
                    current = next;
                }
                level -= 1;
            }

            while let Some(next) = unsafe { (*current).next[0].load(Acquire).as_mut() } {
                prev = current;
                current = next;
            }

            if prev.is_null() {
                self.head.store(ptr::null_mut(), Release);
            } else {
                for level in 0..=unsafe { &*current }.level {
                    unsafe { &*prev }.next[level].store(ptr::null_mut(), Release);
                }
            }

            self.len.fetch_sub(1, Release);
            Some(unsafe { Box::from_raw(current).value })
        }
    }
    #[derive(Clone)]
    pub struct Iter<'a, T, const L: usize> {
        list: &'a List<T, L>,
        curr: *const Node<T>,
        start_version: u64,
        last_observed_version: u64,
        retries: usize,
    }

    impl<'a, T: PartialOrd + 'a, const L: usize> Iter<'a, T, L> {
        const MAX_RETRIES: usize = 3;

        // Helper to validate and advance iterator
        fn try_advance(&mut self) -> Option<&'a T> {
            let current_version = self.list.version.load(Acquire);

            // Update our view of list version
            self.last_observed_version = current_version;

            // If null, we've reached the end
            if self.curr.is_null() {
                return None;
            }

            // Safe because node was valid when we got the pointer
            let node = unsafe { &*self.curr };

            // Get next node before validation
            let next = node.next[0].load(Acquire);

            // Skip if:
            // 1. Node is locked (being modified)
            // 2. Node version is newer than our start version
            // 3. Node has been marked for deletion
            if node.lock.load(Acquire) || node.version.load(Acquire) > self.start_version {
                self.curr = next;
                self.retries += 1;
                return None;
            }

            // Reset retries on successful read
            self.retries = 0;

            // Advance to next node
            self.curr = next;

            Some(&node.value)
        }
    }

    impl<'a, T: PartialOrd + 'a, const L: usize> Iterator for Iter<'a, T, L> {
        type Item = &'a T;

        fn next(&mut self) -> Option<Self::Item> {
            // Keep trying until we get a valid node or definitively reach the end
            loop {
                // Check if we've had too many retries
                if self.retries >= Self::MAX_RETRIES {
                    // Reset position to head and start version to current
                    self.curr = self.list.head.load(Acquire);
                    self.start_version = self.list.version.load(Acquire);
                    self.retries = 0;
                    continue;
                }

                match self.try_advance() {
                    Some(value) => return Some(value),
                    None if self.curr.is_null() => return None, // End of list
                    None => continue,                           // Skip invalid node and retry
                }
            }
        }
    }

    impl<T: PartialOrd, const L: usize> List<T, L>
    where
        [(); L + 1]: Sized,
    {
        pub fn iter(&self) -> Iter<'_, T, L> {
            Iter {
                list: self,
                curr: self.head.load(Acquire),
                start_version: self.version.load(Acquire),
                last_observed_version: self.version.load(Acquire),
                retries: 0,
            }
        }
    }
}
pub use map::{Key, Map};
mod map {
    use super::{List, list::Iter};

    pub trait Key = PartialEq + PartialOrd + Clone;

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

    pub struct Map<K: Key, V> {
        list: List<KeyValue<K, V>>,
    }

    impl<K: Key, V> Default for Map<K, V> {
        fn default() -> Self {
            Self {
                list: Default::default(),
            }
        }
    }

    impl<K: Key, V> Map<K, V> {
        pub async fn get(&self, key: &K) -> Option<&V> {
            self.list
                .get(&KeyValue(key.clone(), None))
                .await
                .map(|kv| kv.1.as_ref())
                .flatten()
        }

        pub async fn insert(&self, key: K, value: V) -> Option<V> {
            self.list
                .insert(KeyValue(key, Some(value)))
                .await
                .map(|kv| kv.1)
                .flatten()
        }

        pub async fn remove(&self, key: &K) -> Option<V> {
            self.list
                .remove(&KeyValue(key.clone(), None))
                .await
                .map(|kv| kv.1)
                .flatten()
        }

        pub async fn contains_key(&self, key: &K) -> bool {
            self.list.exists(&KeyValue(key.clone(), None)).await
        }

        pub fn len(&self) -> usize {
            self.list.len()
        }

        pub fn iter(&self) -> impl Iterator<Item = (&K, &V)> {
            self.list.iter().map(|kv| (&kv.0, kv.1.as_ref().unwrap()))
        }
    }
}
