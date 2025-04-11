use super::skip::{Key, Map};

/// A bidirectional map implementation using lock-free skip lists
#[derive(Default)]
pub struct BiMap<A: Key, B: Key> {
    alpha: Map<A, B>,
    beta: Map<B, A>,
}

impl<A: Key, B: Key> BiMap<A, B> {
    /// Insert a pair of values, replacing any existing mappings
    /// Returns the previous mapping if it existed
    pub async fn insert(&self, a: A, b: B) -> Option<(A, B)> {
        // Handle existing mappings first
        let old_b = self.alpha.get(&a).await.cloned();
        let old_a = self.beta.get(&b).await.cloned();

        // Remove any existing mappings
        if let Some(old_b) = old_b.as_ref() {
            self.beta.remove(old_b).await;
        }
        if let Some(old_a) = old_a.as_ref() {
            self.alpha.remove(old_a).await;
        }

        // Insert new mappings
        self.alpha.insert(a.clone(), b.clone()).await;
        self.beta.insert(b, a).await;

        // Return previous mapping if it existed
        match (old_a, old_b) {
            (Some(a), Some(b)) => Some((a, b)),
            _ => None,
        }
    }

    /// Remove a pair of values by the left key
    pub async fn remove_by_left(&self, a: &A) -> Option<(A, B)> {
        let b = self.alpha.remove(a).await?;
        let a = self.beta.remove(&b).await?;
        Some((a, b))
    }

    /// Remove a pair of values by the right key
    pub async fn remove_by_right(&self, b: &B) -> Option<(A, B)> {
        let a = self.beta.remove(b).await?;
        let b = self.alpha.remove(&a).await?;
        Some((a, b))
    }

    /// Get the right value for a given left key
    #[inline]
    pub async fn get_by_left(&self, a: &A) -> Option<&B> {
        self.alpha.get(a).await
    }

    /// Get the left value for a given right key
    #[inline]
    pub async fn get_by_right(&self, b: &B) -> Option<&A> {
        self.beta.get(b).await
    }

    /// Check if the map contains a left key
    #[inline]
    pub async fn contains_left(&self, a: &A) -> bool {
        self.alpha.contains_key(a).await
    }

    /// Check if the map contains a right key
    #[inline]
    pub async fn contains_right(&self, b: &B) -> bool {
        self.beta.contains_key(b).await
    }

    /// Get the number of pairs in the map
    #[inline]
    pub fn len(&self) -> usize {
        self.alpha.len()
    }

    /// Check if the map is empty
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}
