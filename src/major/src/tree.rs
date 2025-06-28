use std::mem;

pub const MORTON_REPR: usize = 128;
#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Morton<const Order: usize, const Dim: usize = 3>
where
    [(); MORTON_REPR]: Sized,
{
    level: u8,
    bits: [usize; MORTON_REPR],
}

impl<const Order: usize, const Dim: usize> Ord for Morton<Order, Dim>
where
    [(); MORTON_REPR]: Sized,
{
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        // First compare levels (higher level = larger in ordering)
        match self.level.cmp(&other.level) {
            std::cmp::Ordering::Equal => {
                // If levels are equal, compare bits from most significant to least
                for (self_bits, other_bits) in self.bits.iter().zip(other.bits.iter()) {
                    match self_bits.cmp(other_bits) {
                        std::cmp::Ordering::Equal => continue, // Check next chunk of bits
                        ordering => return ordering,
                    }
                }
                // All bits are equal
                std::cmp::Ordering::Equal
            }
            ordering => ordering,
        }
    }
}

impl<const Order: usize, const Dim: usize> PartialOrd for Morton<Order, Dim>
where
    [(); MORTON_REPR]: Sized,
{
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl<const Order: usize, const Dim: usize> Morton<Order, Dim>
where
    [(); MORTON_REPR]: Sized,
{
    const MAX_BYTES: usize = mem::size_of::<usize>() * MORTON_REPR;

    fn max_level() -> usize {
        (Self::MAX_BYTES as f32 / (Order.pow(Dim as u32) as f32).log2().ceil()).floor() as usize
    }
    pub fn encode_position_level(position: [usize; Dim], level: u8) -> Self {
        if level > Self::max_level() as u8 {
            panic!("Level exceeds maximum allowed level");
        }

        let mut bits = [0; MORTON_REPR];
        let bits_per_coord = (Order as f32).log2().ceil() as usize;

        // Process each level of the hierarchy
        for l in 0..level as usize {
            // Process the bits for this level for each dimension
            for bit_pos in 0..bits_per_coord {
                for dim in 0..Dim {
                    // Extract the appropriate bit for this dimension at this level
                    // We work from most significant to least significant bits in the position
                    let shift = (level as usize - l - 1) * bits_per_coord + bit_pos;
                    let bit = (position[dim] >> shift) & 1;

                    // Calculate the position in the Morton code
                    // This is where we interleave bits: dim bits are adjacent for each level
                    let morton_bit_pos = (l * bits_per_coord * Dim) + (bit_pos * Dim) + dim;

                    // Store the bit in the appropriate position in the bits array
                    let array_index = morton_bit_pos / (mem::size_of::<usize>() * 8);
                    let bit_offset = morton_bit_pos % (mem::size_of::<usize>() * 8);

                    if array_index < MORTON_REPR {
                        bits[array_index] |= (bit as usize) << bit_offset;
                    }
                }
            }
        }

        Self { level, bits }
    }
}

pub trait MortonTree<const Order: usize, const Dim: usize> {
    fn node_present(&self, index: usize, level: usize) -> bool {
        // If we haven't encoded anything, no nodes exist
        let encoding_level = self.encoding_level();
        if encoding_level == 0 {
            return false;
        }

        // If the requested level is beyond what we've encoded,
        // check if the parent at the highest encoded level exists
        if level as u8 >= encoding_level {
            // Calculate the parent index at our highest encoded level
            let bits_per_coord = (Order as f32).log2().ceil() as usize;
            let levels_up = level as u8 - encoding_level + 1;
            let parent_index = index >> (levels_up as usize * bits_per_coord * Dim);

            // Check if this parent exists at our highest encoded level
            return self.node_check_at_level(parent_index, (encoding_level - 1) as usize);
        }

        // Otherwise, check if the node exists at the requested level
        return self.node_check_at_level(index, level);
    }
    fn encoding_level(&self) -> u8;
    fn node_check_at_level(&self, index: usize, level: usize) -> bool;
}

impl<const Order: usize, const Dim: usize> MortonTree<Order, Dim> for Morton<Order, Dim>
where
    [(); Order.pow(Dim as u32)]: Sized,
{
    fn node_check_at_level(&self, index: usize, level: usize) -> bool {
        let bits_per_coord = (Order as f32).log2().ceil() as usize;

        // For each dimension, check if the bits match
        for dim in 0..Dim {
            // Extract the dimension value for this index
            let dim_val = (index / Order.pow(dim as u32)) % Order;

            // Check each bit that makes up this dimension's value
            for bit_pos in 0..bits_per_coord {
                // Extract the bit from the dimension value
                let expected_bit = (dim_val >> bit_pos) & 1;

                // Calculate the position in the Morton code
                let morton_bit_pos = (level * bits_per_coord * Dim) + (bit_pos * Dim) + dim;

                // Calculate which element of the bits array and which bit within that element
                let array_index = morton_bit_pos / (mem::size_of::<usize>() * 8);
                let bit_index = morton_bit_pos % (mem::size_of::<usize>() * 8);

                // Check if the bit matches what we expect
                if array_index < MORTON_REPR {
                    let actual_bit = (self.bits[array_index] >> bit_index) & 1;
                    if actual_bit as usize != expected_bit {
                        return false;
                    }
                } else {
                    return false; // Out of range
                }
            }
        }

        return true; // All bits match
    }

    fn encoding_level(&self) -> u8 {
        self.level
    }
}

#[derive(Default)]
pub struct Tree<T, const Subdiv: usize, const Dim: usize = 3>
where
    [(); Subdiv.pow(Dim as u32)]: Sized,
{
    nodes: Vec<Node<T, Subdiv, Dim>>,
    root: Option<usize>,
    // Map from Morton code to node index for O(1) lookups
    position_to_node: std::collections::BTreeMap<Morton<Subdiv, Dim>, usize>,
}

impl<T, const Subdiv: usize, const Dim: usize> Tree<T, Subdiv, Dim>
where
    [(); Subdiv.pow(Dim as u32)]: Sized,
{
    pub fn new() -> Self {
        Self {
            nodes: vec![],
            root: None,
            position_to_node: std::collections::BTreeMap::new(),
        }
    }

    pub fn add_node(&mut self, position: Morton<Subdiv, Dim>, data: T) {
        // Create root node if it doesn't exist
        if self.root.is_none() {
            self.root = Some(0);
            self.nodes.push(Node::new());
            self.nodes[0].data = Some(data);
            self.nodes[0].position = Some(position);
            self.position_to_node.insert(position, 0);
            return;
        }

        let root_idx = self.root.unwrap();
        self.add_node_recursive(root_idx, position, data);
    }

    // Helper method to recursively add a node at the correct position
    fn add_node_recursive(&mut self, node_idx: usize, position: Morton<Subdiv, Dim>, data: T) {
        // Check if the node already exists at this position
        if let Some(&existing_idx) = self.position_to_node.get(&position) {
            // Update the data in the existing node
            self.nodes[existing_idx].data = Some(data);
            return;
        }

        // Calculate the child index based on the position and the parent node's level
        let parent_level = self.nodes[node_idx].position.as_ref().unwrap().level;
        let child_idx = self.calculate_child_index(&position, parent_level as usize);

        // If this child doesn't exist yet, create it
        if self.nodes[node_idx].children[child_idx].is_none() {
            // Add the Morton code for this child
            self.nodes[node_idx].children[child_idx] = Some(position);

            // Create a new node
            let new_node_idx = self.nodes.len();
            let mut new_node = Node::new();
            new_node.data = Some(data);
            new_node.position = Some(position);
            self.nodes.push(new_node);

            // Update the position-to-node mapping
            self.position_to_node.insert(position, new_node_idx);

            return;
        }

        // Child position exists but the node might not
        let child_position = self.nodes[node_idx].children[child_idx].unwrap();

        // Find the child node index using binary search from our mapping
        match self.position_to_node.get(&child_position) {
            Some(&child_node_idx) => {
                // If the existing child is at the same position level, we need to
                // replace its children or recurse further
                if child_position.level == position.level {
                    // Replace data in existing node
                    self.nodes[child_node_idx].data = Some(data);
                    // Update mapping
                    self.position_to_node.insert(position, child_node_idx);
                } else {
                    // Recurse to the child node
                    self.add_node_recursive(child_node_idx, position, data);
                }
            }
            None => {
                // This shouldn't happen in a well-formed tree - we have a child position
                // but no corresponding node. For robustness, create it:
                let new_node_idx = self.nodes.len();
                let mut new_node = Node::new();
                new_node.position = Some(child_position);
                self.nodes.push(new_node);
                self.position_to_node.insert(child_position, new_node_idx);

                // Now recurse to this new node
                self.add_node_recursive(new_node_idx, position, data);
            }
        }
    }

    // Helper to calculate the child index based on the position at a specific level
    fn calculate_child_index(&self, position: &Morton<Subdiv, Dim>, level: usize) -> usize {
        let bits_per_coord = (Subdiv as f32).log2().ceil() as usize;
        let mut index = 0;

        // Extract the relevant bits for each dimension at this level
        for dim in 0..Dim {
            // Calculate base position for this dimension at this level
            let morton_bit_pos_base = (level * bits_per_coord * Dim) + dim;

            for bit_pos in 0..bits_per_coord {
                // Calculate the bit position in the Morton code
                let morton_bit_pos = morton_bit_pos_base + (bit_pos * Dim);

                // Calculate which element of the bits array and which bit within that element
                let array_index = morton_bit_pos / (mem::size_of::<usize>() * 8);
                let bit_index = morton_bit_pos % (mem::size_of::<usize>() * 8);

                // Extract the bit and add it to the index
                if array_index < MORTON_REPR {
                    let bit = (position.bits[array_index] >> bit_index) & 1;
                    index |= (bit as usize) << (dim * bits_per_coord + bit_pos);
                }
            }
        }

        index
    }

    // Find a node by its Morton position using binary search
    pub fn find_node(&self, position: &Morton<Subdiv, Dim>) -> Option<usize> {
        // Direct O(1) lookup using our mapping
        self.position_to_node.get(position).copied()
    }

    // Get nodes in Morton order within a range
    pub fn get_nodes_in_range(
        &self,
        start: &Morton<Subdiv, Dim>,
        end: &Morton<Subdiv, Dim>,
    ) -> Vec<usize> {
        // Use BTreeMap's range functionality to get nodes in Morton order
        self.position_to_node
            .range((
                std::ops::Bound::Included(start),
                std::ops::Bound::Included(end),
            ))
            .map(|(_, &node_idx)| node_idx)
            .collect()
    }
}

pub struct Node<T, const Subdiv: usize, const Dim: usize>
where
    [(); Subdiv.pow(Dim as u32)]: Sized,
{
    children: [Option<Morton<Subdiv, Dim>>; Subdiv.pow(Dim as u32)],
    data: Option<T>,
    position: Option<Morton<Subdiv, Dim>>, // Store the node's own position
}

impl<T, const Subdiv: usize, const Dim: usize> Node<T, Subdiv, Dim>
where
    [(); Subdiv.pow(Dim as u32)]: Sized,
{
    pub fn new() -> Self {
        Self {
            children: [None; Subdiv.pow(Dim as u32)],
            data: None,
            position: None,
        }
    }
}
