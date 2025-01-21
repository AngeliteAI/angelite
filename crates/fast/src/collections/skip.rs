pub use list::List;
pub mod list {
    use std::{
        cmp::Ordering,
        convert::identity,
        iter,
        marker::PhantomData,
        ptr,
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

    struct Node<T> {
        value: Option<T>,
        next: Vec<AtomicPtr<Node<T>>>, // Vector of next pointers at each level
        marked: Vec<AtomicBool>,       // Marked flags for logical deletion at each level
    }

    impl<T> Node<T> {
        fn new(value: Option<T>, height: usize) -> Self {
            // Ensure at least one level
            let height = height.max(1);
            let mut next = Vec::with_capacity(height);
            let mut marked = Vec::with_capacity(height);

            // Initialize all levels
            for _ in 0..height {
                next.push(AtomicPtr::new(ptr::null_mut()));
                marked.push(AtomicBool::new(false));
            }

            Self {
                value,
                next,
                marked,
            }
        }
    }
    impl<T: PartialOrd, const L: usize> List<T, L> {
        pub fn new() -> Self {
            // Create sentinel head node with maximum height L
            let head = Box::new(Node::new(None, L));
            let head_ptr = Box::into_raw(head);

            Self {
                version: Arc::new(AtomicU64::new(0)),
                head: Arc::new(AtomicPtr::new(head_ptr)),
                level: Arc::new(AtomicUsize::new(0)),
                len: Arc::new(AtomicUsize::new(0)),
            }
        }

        pub async fn insert(&self, value: T) -> Option<T> {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));
            let height = if self.is_empty() {
                0
            } else {
                self.random_level().await
            };

            let node = Box::new(Node::new(Some(value), height + 1));
            let node_ptr = Box::into_raw(node);

            loop {
                if let Some(old_value) = self.try_insert(node_ptr, height).await {
                    return old_value;
                }
                backoff.wait().await;
            }
        }

        pub async fn first(&self) -> Option<&T> {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            loop {
                let head = self.head.load(Acquire);
                if head.is_null() {
                    return None;
                }

                // Safely access head
                let head_ref = unsafe { &*head };
                if head_ref.next.is_empty() {
                    return None;
                }

                // Get first potential node
                let mut current = head_ref.next[0].load(Acquire);

                // Traverse until we find first valid node
                while !current.is_null() {
                    // Validate pointer before dereferencing
                    let current_ref = match unsafe { current.as_ref() } {
                        Some(r) => r,
                        None => {
                            backoff.wait().await;
                            continue;
                        }
                    };

                    // Check if node is valid
                    if current_ref.next.is_empty() || current_ref.marked.is_empty() {
                        backoff.wait().await;
                        continue;
                    }

                    // Check if node is logically deleted
                    if !current_ref.marked[0].load(Acquire) {
                        // Found first non-deleted node
                        return current_ref.value.as_ref();
                    }

                    // Move to next node
                    current = current_ref.next[0].load(Acquire);
                }

                // No valid nodes found
                return None;
            }
        }

        pub fn last(&self) -> Option<&T> {
            let head = self.head.load(Acquire);
            if head.is_null() {
                return None;
            }

            let head_ref = unsafe { &*head };
            if head_ref.next.len() == 0 {
                return None;
            }

            let mut current = head_ref.next[0].load(Acquire);
            let mut last = None;

            while !current.is_null() {
                let current_ref = unsafe { &*current };

                // Validate vectors before accessing
                if current_ref.next.len() == 0 || current_ref.marked.len() == 0 {
                    break;
                }

                if !current_ref.marked[0].load(Acquire) {
                    last = current_ref.value.as_ref();
                }
                current = current_ref.next[0].load(Acquire);
            }
            last
        }
        async fn find_node(
            &self,
            value: &T,
            preds: &mut Vec<*mut Node<T>>,
            succs: &mut Vec<*mut Node<T>>,
        ) -> bool {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            'retry: loop {
                let mut pred = self.head.load(Acquire);
                if pred.is_null() {
                    return false;
                }

                let level = self.level.load(Acquire).min(L - 1);

                // Initialize vectors
                preds.clear();
                succs.clear();
                preds.extend(std::iter::repeat(ptr::null_mut()).take(L));
                succs.extend(std::iter::repeat(ptr::null_mut()).take(L));

                // Search from top down
                for current_level in (0..=level).rev() {
                    let mut pred_ref = match unsafe { pred.as_ref() } {
                        Some(r) => r,
                        None => {
                            backoff.wait().await;
                            continue 'retry;
                        }
                    };

                    if pred_ref.next.len() <= current_level {
                        continue;
                    }

                    let mut curr = pred_ref.next[current_level].load(Acquire);

                    loop {
                        if curr.is_null() {
                            break;
                        }

                        // Safely get current node reference
                        let curr_ref = match unsafe { curr.as_ref() } {
                            Some(r) => r,
                            None => {
                                backoff.wait().await;
                                continue 'retry;
                            }
                        };

                        // Validate current node's structure
                        if curr_ref.next.len() <= current_level
                            || curr_ref.marked.len() <= current_level
                        {
                            backoff.wait().await;
                            continue 'retry;
                        }

                        let succ = curr_ref.next[current_level].load(Acquire);

                        // Handle logically deleted nodes
                        if !succ.is_null() {
                            let mut is_marked = false;
                            let mut next = succ;

                            while !next.is_null() {
                                let next_ref = match unsafe { next.as_ref() } {
                                    Some(r) => r,
                                    None => {
                                        backoff.wait().await;
                                        continue 'retry;
                                    }
                                };

                                if next_ref.marked.len() <= current_level {
                                    backoff.wait().await;
                                    continue 'retry;
                                }

                                is_marked = next_ref.marked[current_level].load(Acquire);
                                if !is_marked {
                                    break;
                                }
                                next = next_ref.next[current_level].load(Acquire);
                            }

                            if is_marked {
                                // Try to physically remove
                                let _ = curr_ref.next[current_level]
                                    .compare_exchange(succ, next, AcqRel, Acquire);
                                curr = next;
                                continue;
                            }
                        }

                        match &curr_ref.value {
                            Some(curr_value) if curr_value < value => {
                                pred = curr;
                                pred_ref = curr_ref;
                                curr = succ;
                            }
                            Some(curr_value) if curr_value == value => {
                                preds[current_level] = pred;
                                succs[current_level] = curr;
                                break;
                            }
                            _ => break,
                        }
                    }

                    // Update level pointers
                    if curr.is_null()
                        || unsafe { (*curr).value.as_ref() }.map_or(true, |v| v > value)
                    {
                        preds[current_level] = pred;
                        succs[current_level] = curr;
                    }
                }
                return true;
            }
        }
        async fn try_insert(&self, new_node: *mut Node<T>, height: usize) -> Option<Option<T>> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            if !self
                .find_node(
                    unsafe { (*new_node).value.as_ref().unwrap() },
                    &mut preds,
                    &mut succs,
                )
                .await
            {
                return None;
            }

            // Try insert at bottom level first
            unsafe {
                let pred = preds[0];
                if pred.is_null() {
                    return None;
                }
                let succ = succs[0];
                (*new_node).next[0].store(succ, Release);

                if (*pred).next[0]
                    .compare_exchange(succ, new_node, AcqRel, Acquire)
                    .is_err()
                {
                    return None;
                }
            }

            // Insert at higher levels after bottom success
            for level in 1..=height.min(L - 1) {
                loop {
                    unsafe {
                        let pred = preds[level];
                        if pred.is_null() {
                            break;
                        }

                        if (*pred).next.len() <= level {
                            break;
                        }

                        let succ = succs[level];
                        (*new_node).next[level].store(succ, Release);

                        match (*pred).next[level].compare_exchange(succ, new_node, AcqRel, Acquire)
                        {
                            Ok(_) => break,
                            Err(_) => {
                                if !self
                                    .find_node(
                                        (*new_node).value.as_ref().unwrap(),
                                        &mut preds,
                                        &mut succs,
                                    )
                                    .await
                                {
                                    return None;
                                }
                            }
                        }
                    }
                }
            }

            self.len.fetch_add(1, Release);
            Some(None)
        }

        pub fn remove_first(&self) -> Option<T> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            // Initialize vectors
            preds.clear();
            succs.clear();
            preds.extend(std::iter::repeat(ptr::null_mut::<Node<T>>()).take(L));
            succs.extend(std::iter::repeat(ptr::null_mut::<Node<T>>()).take(L));

            let head = self.head.load(Acquire);
            let first = unsafe { (*head).next[0].load(Acquire) };

            if first.is_null() {
                return None;
            }

            unsafe {
                let first_ref = &*first;

                // Check if already marked
                if first_ref.marked[0].load(Acquire) {
                    return None;
                }

                // Mark for deletion from top down
                for level in (1..first_ref.next.len()).rev() {
                    loop {
                        if first_ref.marked[level].load(Acquire) {
                            break; // Already marked at this level
                        }
                        if first_ref.marked[level]
                            .compare_exchange(false, true, AcqRel, Acquire)
                            .is_ok()
                        {
                            break;
                        }
                    }
                }

                // Mark bottom level last = logical deletion
                if !first_ref.marked[0]
                    .compare_exchange(false, true, AcqRel, Acquire)
                    .is_ok()
                {
                    return None; // Already deleted
                }

                // Physical deletion
                for level in 0..first_ref.next.len() {
                    let next = first_ref.next[level].load(Acquire);
                    let _ = (*head).next[level].compare_exchange(first, next, AcqRel, Acquire);
                }

                self.len.fetch_sub(1, Release);
                return Some(Box::from_raw(first).value.unwrap());
            }
        }

        pub fn remove_last(&self) -> Option<T> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            // Initialize vectors
            preds.extend(std::iter::repeat(ptr::null_mut::<Node<T>>()).take(L));
            succs.extend(std::iter::repeat(ptr::null_mut::<Node<T>>()).take(L));

            // Find last non-marked node at bottom level
            let mut pred = self.head.load(Acquire);
            let mut curr = unsafe { (*pred).next[0].load(Acquire) };
            let mut last = ptr::null_mut();
            let mut last_pred = ptr::null_mut();

            while !curr.is_null() {
                unsafe {
                    if !(*curr).marked[0].load(Acquire) {
                        last = curr;
                        last_pred = pred;
                    }
                    pred = curr;
                    curr = (*curr).next[0].load(Acquire);
                }
            }

            if last.is_null() {
                return None;
            }

            unsafe {
                let last_ref = &*last;

                // Check if already marked
                if last_ref.marked[0].load(Acquire) {
                    return None;
                }

                // Mark for deletion from top down
                for level in (1..last_ref.next.len()).rev() {
                    loop {
                        if last_ref.marked[level].load(Acquire) {
                            break; // Already marked at this level
                        }
                        if last_ref.marked[level]
                            .compare_exchange(false, true, AcqRel, Acquire)
                            .is_ok()
                        {
                            break;
                        }
                    }
                }

                // Mark bottom level last = logical deletion
                if !last_ref.marked[0]
                    .compare_exchange(false, true, AcqRel, Acquire)
                    .is_ok()
                {
                    return None; // Already deleted
                }

                // Physical deletion
                for level in 0..last_ref.next.len() {
                    let next = last_ref.next[level].load(Acquire);
                    if !last_pred.is_null() {
                        let _ =
                            (*last_pred).next[level].compare_exchange(last, next, AcqRel, Acquire);
                    }
                }

                self.len.fetch_sub(1, Release);
                return Some(Box::from_raw(last).value.unwrap());
            }
        }

        pub async fn remove(&self, value: &T) -> Option<T> {
            let backoff = Backoff::with_step(Duration::<Millis>::from(5));

            loop {
                let mut preds = Vec::with_capacity(L);
                let mut succs = Vec::with_capacity(L);

                // Find node
                if !self.find_node(value, &mut preds, &mut succs).await {
                    return None;
                }

                let target = succs[0];
                if target.is_null() {
                    return None;
                }

                unsafe {
                    let target_ref = &*target;
                    if target_ref.value.as_ref() != Some(value) {
                        return None;
                    }

                    // Mark for deletion from top down
                    for level in (1..target_ref.next.len()).rev() {
                        let mut succ;
                        loop {
                            succ = target_ref.next[level].load(Acquire);
                            if target_ref.marked[level].load(Acquire) {
                                break; // Already marked at this level
                            }
                            if target_ref.marked[level]
                                .compare_exchange(false, true, AcqRel, Acquire)
                                .is_ok()
                            {
                                break;
                            }
                        }
                    }

                    // Mark bottom level last = logical deletion
                    let mut succ = target_ref.next[0].load(Acquire);
                    loop {
                        if target_ref.marked[0].load(Acquire) {
                            return None; // Already deleted
                        }
                        if target_ref.marked[0]
                            .compare_exchange(false, true, AcqRel, Acquire)
                            .is_ok()
                        {
                            break;
                        }
                        backoff.wait().await;
                    }

                    // Physical deletion - help remove
                    self.find_node(value, &mut preds, &mut succs).await;

                    self.len.fetch_sub(1, Release);
                    return Some(Box::from_raw(target).value.unwrap());
                }
            }
        }

        pub async fn get(&self, value: &T) -> Option<&T> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            // Must check bottom level
            if !self.find_node(value, &mut preds, &mut succs).await {
                return None;
            }

            let node = succs[0];
            unsafe {
                if !node.is_null() && !(*node).marked[0].load(Acquire) {
                    if let Some(node_value) = (*node).value.as_ref() {
                        if node_value == value {
                            return Some(node_value);
                        }
                    }
                }
            }
            None
        }

        pub async fn exists(&self, value: &T) -> bool {
            self.get(value).await.is_some()
        }

        async fn random_level(&self) -> usize {
            let mut level = 0;
            while level < L - 1 && random::<bool>().await.unwrap_or_default() {
                level += 1;
            }
            level.min(L - 1)
        }

        pub fn len(&self) -> usize {
            self.len.load(Acquire)
        }

        pub fn is_empty(&self) -> bool {
            self.len() == 0
        }

        // Iterator implementation
        pub fn iter(&self) -> Iter<'_, T, L> {
            Iter {
                curr: unsafe { (*self.head.load(Acquire)).next[0].load(Acquire) },
                _marker: PhantomData,
            }
        }
    }
    pub struct Iter<'a, T, const L: usize> {
        curr: *mut Node<T>,
        _marker: PhantomData<&'a T>,
    }

    impl<'a, T: 'a, const L: usize> Iterator for Iter<'a, T, L> {
        type Item = &'a T;

        fn next(&mut self) -> Option<Self::Item> {
            while !self.curr.is_null() {
                let current = unsafe { &*self.curr };
                self.curr = current.next[0].load(Acquire);

                // Skip logically deleted nodes
                if !current.marked[0].load(Acquire) {
                    if let Some(value) = &current.value {
                        return Some(value);
                    }
                }
            }
            None
        }
    }

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
            Self { list: List::new() }
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

        pub async fn first(&self) -> Option<(&K, &V)> {
            self.list
                .first()
                .await
                .map(|kv| (&kv.0, kv.1.as_ref().unwrap()))
        }

        /// Returns a reference to the last key-value pair
        pub fn last(&self) -> Option<(&K, &V)> {
            self.list.last().map(|kv| (&kv.0, kv.1.as_ref().unwrap()))
        }

        /// Returns a reference to the first key
        pub async fn first_key(&self) -> Option<&K> {
            self.first().await.map(|(k, _)| k)
        }

        /// Returns a reference to the last key
        pub fn last_key(&self) -> Option<&K> {
            self.last().map(|(k, _)| k)
        }

        /// Returns a reference to the first value
        pub async fn first_value(&self) -> Option<&V> {
            self.first().await.map(|(_, v)| v)
        }

        /// Returns a reference to the last value
        pub fn last_value(&self) -> Option<&V> {
            self.last().map(|(_, v)| v)
        }

        pub async fn remove(&self, key: &K) -> Option<V> {
            self.list
                .remove(&KeyValue(key.clone(), None))
                .await
                .map(|kv| kv.1)
                .flatten()
        }

        /// Removes and returns the first key-value pair
        pub fn remove_first(&self) -> Option<(K, V)> {
            self.list.remove_first().map(|kv| {
                // KeyValue contains (K, Option<V>) - we know V exists in valid maps
                (kv.0, kv.1.unwrap())
            })
        }

        /// Removes and returns the last key-value pair
        pub fn remove_last(&self) -> Option<(K, V)> {
            self.list.remove_last().map(|kv| (kv.0, kv.1.unwrap()))
        }

        /// Removes and returns only the first value, discarding the key
        pub fn remove_first_value(&self) -> Option<V> {
            self.remove_first().map(|(_, v)| v)
        }

        /// Removes and returns only the last value, discarding the key
        pub fn remove_last_value(&self) -> Option<V> {
            self.remove_last().map(|(_, v)| v)
        }

        /// Removes the first entry and returns only the key
        pub fn remove_first_key(&self) -> Option<K> {
            self.remove_first().map(|(k, _)| k)
        }

        /// Removes the last entry and returns only the key
        pub fn remove_last_key(&self) -> Option<K> {
            self.remove_last().map(|(k, _)| k)
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
