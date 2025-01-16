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
            let mut next = Vec::with_capacity(height);
            let mut marked = Vec::with_capacity(height);
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
            let height = self.random_level().await;

            let node = Box::new(Node::new(Some(value), height + 1));
            let node_ptr = Box::into_raw(node);

            loop {
                if let Some(old_value) = self.try_insert(node_ptr, height).await {
                    return old_value;
                }
                backoff().await;
            }
        }

        async fn try_insert(&self, new_node: *mut Node<T>, height: usize) -> Option<Option<T>> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            if !self.find_node(
                unsafe { (*new_node).value.as_ref().unwrap() },
                &mut preds,
                &mut succs,
            ) {
                return None;
            }

            // Check if exists in bottom level first
            if let Some(succ) = unsafe { succs[0].as_ref() } {
                if !succ.marked[0].load(Acquire) {
                    if let Some(_) = &succ.value {
                        if let Some(succ_value) = unsafe { (*new_node).value.take() } {
                            return Some(Some(succ_value)); // Already exists
                        }
                    }
                }
            }

            // Try insert at bottom level first
            unsafe {
                let pred = &*preds[0];
                (*new_node).next[0].store(succs[0], Release);

                if pred.next[0]
                    .compare_exchange(succs[0], new_node, AcqRel, Acquire)
                    .is_err()
                {
                    return None; // Retry if bottom level insertion fails
                }
            }

            // Insert at higher levels after bottom success
            for level in 1..=height {
                loop {
                    unsafe {
                        let pred = &*preds[level];
                        let succ = succs[level];

                        (*new_node).next[level].store(succ, Release);

                        if pred.next[level]
                            .compare_exchange(succ, new_node, AcqRel, Acquire)
                            .is_ok()
                        {
                            break; // Success at this level
                        }

                        // Find new position if CAS failed
                        if !self.find_node(
                            (*new_node).value.as_ref().unwrap(),
                            &mut preds,
                            &mut succs,
                        ) {
                            return None;
                        }
                    }
                }
            }

            self.len.fetch_add(1, Release);
            Some(None) // Successful insertion
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
                if !self.find_node(value, &mut preds, &mut succs) {
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
                        backoff().await;
                    }

                    // Physical deletion - help remove
                    self.find_node(value, &mut preds, &mut succs);

                    self.len.fetch_sub(1, Release);
                    return Some(Box::from_raw(target).value.unwrap());
                }
            }
        }

        pub async fn get(&self, value: &T) -> Option<&T> {
            let mut preds = Vec::with_capacity(L);
            let mut succs = Vec::with_capacity(L);

            // Must check bottom level
            if !self.find_node(value, &mut preds, &mut succs) {
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

        fn find_node(
            &self,
            value: &T,
            preds: &mut Vec<*mut Node<T>>,
            succs: &mut Vec<*mut Node<T>>,
        ) -> bool {
            'retry: loop {
                let mut pred = self.head.load(Acquire);
                let level = self.level.load(Acquire).min(L - 1);

                // Initialize vectors
                preds.clear();
                succs.clear();
                preds.extend(std::iter::repeat(ptr::null_mut()).take(L));
                succs.extend(std::iter::repeat(ptr::null_mut()).take(L));

                // Search from top down
                for current_level in (0..=level).rev() {
                    let mut curr = unsafe { (*pred).next[current_level].load(Acquire) };

                    // Skip marked nodes at this level
                    loop {
                        if curr.is_null() {
                            break;
                        }

                        let curr_ref = unsafe { &*curr };
                        let succ = curr_ref.next[current_level].load(Acquire);

                        // Skip logically deleted nodes
                        while !succ.is_null()
                            && unsafe { (*succ).marked[current_level].load(Acquire) }
                        {
                            let next = unsafe { (*succ).next[current_level].load(Acquire) };
                            // Try to physically remove
                            let _ = curr_ref.next[current_level]
                                .compare_exchange(succ, next, AcqRel, Acquire);
                            curr = next;
                        }

                        match &curr_ref.value {
                            Some(curr_value) if curr_value < value => {
                                pred = curr;
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

                    if curr.is_null() || unsafe { (*curr).value.as_ref().unwrap() > value } {
                        preds[current_level] = pred;
                        succs[current_level] = curr;
                    }
                }
                return true;
            }
        }

        async fn random_level(&self) -> usize {
            let mut level = 0;
            while level < L - 1 && random::<bool>().await.unwrap_or_default() {
                level += 1;
            }
            level
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
