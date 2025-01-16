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

    pub struct List<T, const L: usize = 32> {
        version: Arc<AtomicU64>,
        head: Arc<AtomicPtr<Node<T>>>,
        level: Arc<AtomicUsize>,
        len: Arc<AtomicUsize>,
    }

    impl<T: PartialOrd, const L: usize> Default for List<T, L> {
        fn default() -> Self {
            Self::new()
        }
    }

    // Safe cleanup
    impl<T, const L: usize> Drop for List<T, L> {
        fn drop(&mut self) {
            let mut current = self.head.load(Acquire);
            while !current.is_null() {
                let next = unsafe { (*current).next[0].load(Acquire) };
                unsafe { drop(Box::from_raw(current)) };
                current = next;
            }
        }
    }

    struct Node<T> {
        value: Option<T>,
        version: AtomicU64,
        lock: AtomicBool,
        next: Vec<AtomicPtr<Node<T>>>,
        level: usize,
    }
    impl<T> Node<T> {
        fn new(value: Option<T>, level: usize) -> Self {
            Self {
                value,
                version: 0.into(),
                lock: false.into(),
                next: iter::repeat_with(|| AtomicPtr::new(ptr::null_mut()))
                    .take(level)
                    .collect(),
                level,
            }
        }
    }

    #[derive(Debug)]
    pub struct Contention;

    impl<T: PartialOrd, const L: usize> List<T, L> {
        pub fn new() -> Self {
            // Create sentinel head node with maximum level
            let head = Box::new(Node::new(
                None, L, // Always use max level for head
            ));
            let head_ptr = Box::into_raw(head);

            Self {
                version: Arc::new(AtomicU64::new(0)),
                head: Arc::new(AtomicPtr::new(head_ptr)),
                level: Arc::new(AtomicUsize::new(0)),
                len: Arc::new(AtomicUsize::new(0)),
            }
        }

        pub async fn get(&self, value: &T) -> Option<&T> {
            let mut current = self.head.load(Acquire);
            if current.is_null() {
                return None;
            }

            let max_level = self.level.load(Acquire).min(L - 1);

            for level in (0..=max_level).rev() {
                loop {
                    // Safety check - validate current pointer
                    let current_node = match unsafe { current.as_ref() } {
                        Some(node) => node,
                        None => break,
                    };

                    // Bounds check for current node's next array
                    if level >= current_node.next.len() {
                        break;
                    }

                    let next_ptr = current_node.next[level].load(Acquire);
                    if next_ptr.is_null() {
                        break;
                    }

                    // Safety check - validate next pointer
                    let next_node = match unsafe { next_ptr.as_ref() } {
                        Some(node) => node,
                        None => break,
                    };

                    if next_node.lock.load(Acquire) {
                        break;
                    }

                    match next_node.value.as_ref().unwrap().partial_cmp(value) {
                        Some(Ordering::Less) => {
                            current = next_ptr;
                            continue;
                        }
                        Some(Ordering::Equal) => return Some(next_node.value.as_ref().unwrap()),
                        Some(Ordering::Greater) | None => break,
                    }
                }
            }
            None
        }
        pub async fn insert(&self, value: T) -> Option<T> {
            // Calculate random level with fixed bounds
            let mut level = 0;
            for i in 0..L - 1 {
                // L-1 since we're 0-indexed
                if random::<bool>().await.unwrap_or_default() {
                    level = i;
                }
            }

            // Create new node with Some(value)
            let node = Arc::new(Node::new(Some(value), level + 1));
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            loop {
                // Find insertion path or existing node
                let (prev_value, path) = match self.find_path(&node.value.as_ref().unwrap()).await {
                    // Found existing node - remove it first
                    Ok(found_path) => {
                        let prev = self.remove(&node.value.as_ref().unwrap()).await;
                        (prev, found_path)
                    }
                    // No existing node - use found path
                    Err(not_found_path) => (None, not_found_path),
                };

                // Try to insert at found path
                match self.try_insert(&node, &path, level).await {
                    Ok(_) => return prev_value,
                    Err(_) => {
                        backoff().await;
                        continue;
                    }
                }
            }
        }

        // Adjust comparisons to handle Option
        async fn find_path(&self, value: &T) -> Result<Vec<*mut Node<T>>, Vec<*mut Node<T>>> {
            let mut update = vec![ptr::null_mut(); L];
            let mut current = self.head.load(Acquire);

            if current.is_null() {
                return Err(update);
            }

            let max_level = self.level.load(Acquire).min(L - 1);

            for level in (0..=max_level).rev() {
                loop {
                    let current_node = match unsafe { current.as_ref() } {
                        Some(node) => node,
                        None => break,
                    };

                    if level >= current_node.next.len() {
                        update[level] = current;
                        break;
                    }

                    let next_ptr = current_node.next[level].load(Acquire);
                    if next_ptr.is_null() {
                        update[level] = current;
                        break;
                    }

                    let next_node = match unsafe { next_ptr.as_ref() } {
                        Some(node) => node,
                        None => {
                            update[level] = current;
                            break;
                        }
                    };

                    if next_node.lock.load(Acquire) {
                        update[level] = current;
                        break;
                    }

                    match &next_node.value {
                        Some(next_value) => match next_value.partial_cmp(value) {
                            Some(Ordering::Less) => {
                                current = next_ptr;
                                continue;
                            }
                            Some(Ordering::Equal) => {
                                for l in 0..=level {
                                    update[l] = current;
                                }
                                update[level] = next_ptr;
                                return Ok(update);
                            }
                            Some(Ordering::Greater) | None => {
                                update[level] = current;
                                break;
                            }
                        },
                        None => {
                            update[level] = current;
                            break;
                        }
                    }
                }
            }

            Err(update)
        }

        pub async fn exists(&self, value: &T) -> bool {
            let mut current = self.head.load(Acquire);
            if current.is_null() {
                return false;
            }

            let max_level = self.level.load(Acquire).min(L - 1);

            for level in (0..=max_level).rev() {
                loop {
                    // Safety check - validate current pointer
                    let current_node = match unsafe { current.as_ref() } {
                        Some(node) => node,
                        None => break,
                    };

                    // Bounds check for current node's next array
                    if level >= current_node.next.len() {
                        break;
                    }

                    let next_ptr = current_node.next[level].load(Acquire);
                    if next_ptr.is_null() {
                        break;
                    }

                    // Safety check - validate next pointer
                    let next_node = match unsafe { next_ptr.as_ref() } {
                        Some(node) => node,
                        None => break,
                    };

                    // Skip locked nodes
                    if next_node.lock.load(Acquire) {
                        break;
                    }

                    match next_node.value.as_ref().unwrap().partial_cmp(value) {
                        Some(Ordering::Less) => {
                            current = next_ptr;
                            continue;
                        }
                        Some(Ordering::Equal) => return true,
                        Some(Ordering::Greater) | None => break,
                    }
                }
            }

            false
        }

        async fn try_insert(
            &self,
            node: &Arc<Node<T>>,
            update: &[*mut Node<T>],
            level: usize,
        ) -> Result<(), Contention> {
            let new_version = self.version.fetch_add(1, Release);

            // SAFETY: We already validate update path in find_path
            // Don't validate pointers again - they're already checked
            node.version.store(new_version, Release);

            // Try to insert at each level
            for current_level in 0..=level {
                // SAFETY: We know update[current_level] is valid from find_path
                let update_node = unsafe { &*update[current_level] };
                let next = update_node.next[current_level].load(Acquire);

                // Store next pointer in new node
                if let Some(node_next) = node.next.get(current_level) {
                    node_next.store(next, Release);
                } else {
                    return Err(Contention);
                }

                // Try to link new node
                if update_node.next[current_level]
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

        pub async fn remove(&self, value: &T) -> Option<T> {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            loop {
                let path = match self.find_path(value).await {
                    Ok(path) => path,
                    Err(_) => return None,
                };

                let node_ptr = path[0];
                if node_ptr.is_null() {
                    return None;
                }

                let node = unsafe { &*node_ptr };
                if node.value.as_ref() != Some(value) {
                    return None;
                }

                match self.try_remove(node_ptr, &path).await {
                    Ok(value) => return Some(value),
                    Err(_) => {
                        backoff().await;
                        continue;
                    }
                }
            }
        }

        async fn try_remove(
            &self,
            node_ptr: *mut Node<T>,
            update: &[*mut Node<T>],
        ) -> Result<T, Contention> {
            let node = unsafe { &*node_ptr };

            if !node
                .lock
                .compare_exchange(false, true, AcqRel, Acquire)
                .is_ok()
            {
                return Err(Contention);
            }

            let new_version = self.version.fetch_add(1, Release);

            for level in 0..=node.level {
                if let Some(update_node) = unsafe { update[level].as_ref() } {
                    update_node.version.store(new_version, Release);
                } else {
                    node.lock.store(false, Release);
                    return Err(Contention);
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
                    node.lock.store(false, Release);
                    return Err(Contention);
                }
            }

            self.len.fetch_sub(1, Release);
            Ok(unsafe { Box::from_raw(node_ptr).value.unwrap() })
        }

        pub fn len(&self) -> usize {
            self.len.load(Acquire)
        }

        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        pub fn remove_last(&self) -> Option<T> {
            loop {
                let mut current = self.head.load(Acquire);
                let mut prev = ptr::null_mut();
                let mut last_ptr = ptr::null_mut();

                // Find the last node
                while let Some(current_node) = unsafe { current.as_ref() } {
                    match unsafe { current_node.next[0].load(Acquire).as_ref() } {
                        Some(_) => {
                            prev = current;
                            current = current_node.next[0].load(Acquire);
                        }
                        None => {
                            last_ptr = current;
                            break;
                        }
                    }
                }

                // No nodes or only sentinel
                if last_ptr.is_null() || prev.is_null() {
                    return None;
                }

                let last = unsafe { &*last_ptr };

                // Try to acquire lock
                if !last
                    .lock
                    .compare_exchange(false, true, AcqRel, Acquire)
                    .is_ok()
                {
                    continue;
                }

                let prev_node = unsafe { &*prev };
                let max_level = last.level;
                let mut success = true;

                // Update all levels
                for level in 0..=max_level {
                    if level >= prev_node.next.len() {
                        success = false;
                        break;
                    }

                    if prev_node.next[level]
                        .compare_exchange(last_ptr, ptr::null_mut(), AcqRel, Acquire)
                        .is_err()
                    {
                        success = false;
                        break;
                    }
                }

                if !success {
                    last.lock.store(false, Release);
                    continue;
                }

                self.len.fetch_sub(1, Release);

                // Update max level if needed
                if max_level == self.level.load(Acquire) {
                    let mut new_max = 0;
                    let mut scan = self.head.load(Acquire);

                    while let Some(node) = unsafe { scan.as_ref() } {
                        new_max = new_max.max(node.level);
                        if let Some(next_ptr) = unsafe { node.next[0].load(Acquire).as_ref() } {
                            scan = node.next[0].load(Acquire);
                        } else {
                            break;
                        }
                    }

                    self.level.fetch_min(new_max, Release);
                }

                return Some(
                    unsafe { Box::from_raw(last_ptr as *mut Node<T>) }
                        .value
                        .unwrap(),
                );
            }
        }
        pub fn remove_first(&self) -> Option<T> {
            loop {
                let head = self.head.load(Acquire);
                if head.is_null() {
                    return None;
                }

                // Get first real node (after sentinel)
                let head_node = unsafe { &*head };
                let first_ptr = head_node.next[0].load(Acquire);

                // Empty list (only sentinel)
                if first_ptr.is_null() {
                    return None;
                }

                let first = unsafe { &*first_ptr };

                // Try to acquire lock
                if !first
                    .lock
                    .compare_exchange(false, true, AcqRel, Acquire)
                    .is_ok()
                {
                    continue;
                }

                let max_level = first.level;
                let mut success = true;

                // Update all levels of the head node
                for level in 0..=max_level {
                    if level >= head_node.next.len() {
                        success = false;
                        break;
                    }

                    let next = first.next[level].load(Acquire);
                    if head_node.next[level]
                        .compare_exchange(first_ptr, next, AcqRel, Acquire)
                        .is_err()
                    {
                        success = false;
                        break;
                    }
                }

                if !success {
                    first.lock.store(false, Release);
                    continue;
                }

                self.len.fetch_sub(1, Release);

                // Update max level if needed
                if max_level == self.level.load(Acquire) {
                    let mut new_max = 0;
                    let mut scan = self.head.load(Acquire);

                    while let Some(node) = unsafe { scan.as_ref() } {
                        new_max = new_max.max(node.level);
                        if let Some(next_ptr) = unsafe { node.next[0].load(Acquire).as_ref() } {
                            scan = node.next[0].load(Acquire);
                        } else {
                            break;
                        }
                    }

                    self.level.fetch_min(new_max, Release);
                }

                return Some(unsafe { Box::from_raw(first_ptr) }.value.unwrap());
            }
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

            Some(node.value.as_ref().unwrap())
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
