use crate::system::func::{Provider, Wrap};
use crate::system::graph::Graph;
use crate::system::sequence::Sequence;
use crate::world::World;
use base::collections::array::Array;
use base::rt::join::UnorderedJoin;
use base::{collections::queue::Queue, rt::spawn};
use std::collections::{HashMap, HashSet, VecDeque};
use std::env::args;
use std::iter;

#[derive(Default)]
pub struct Schedule {
    graph: Graph,
}
impl Schedule {
    pub async fn run(&mut self, world: &mut World) {
        let mut nodes_ready = VecDeque::default();
        let mut nodes_pending = HashMap::new();
        let mut nodes_completed = HashSet::new();

        // Initialize dependency tracking
        for (id, _) in &self.graph.nodes {
            let deps = self.graph.dependencies(id);
            if deps.is_empty() {
                nodes_ready.push_front(id.clone());
            } else {
                nodes_pending.insert(id.clone(), deps.len());
            }
        }

        while !nodes_ready.is_empty() {
            // Collect batch of ready nodes
            let mut batch = Vec::<_>::new();
            while let Some(node_id) = nodes_ready.pop_back() {
                if let Some(node) = self.graph.nodes.remove(&node_id) {
                    batch.push((node_id, node));
                }
            }

            // Prepare and launch tasks
            let mut join = UnorderedJoin::<_>::new();

            for (node_id, mut node) in batch {
                // Prepare node input data
                let table_count = node.put.prepare(&mut world.registry);

                // Create system task
                join.push(async move {
                    // Execute system
                    dbg!("stock");
                    for _ in 0..table_count {
                        (node.system)(node.rx.clone())
                            .await
                            .map_err(|_| ())
                            .expect("YO");
                    }
                    dbg!("poop");
                    (node_id, node)
                });
            }

            // Wait for all tasks to complete in any order
            let completed = join.await;

            // Process completed tasks
            for (completed_id, node) in completed {
                // Restore node and mark completed
                self.graph.nodes.insert(completed_id.clone(), node);
                nodes_completed.insert(completed_id.clone());

               // update dependent nodes
                for dependent in self.graph.dependents(&completed_id) {
                    if let Some(pending_count) = nodes_pending.get_mut(&dependent) {
                        *pending_count -= 1;
                        if *pending_count == 0 {
                            nodes_pending.remove(&dependent);
                            nodes_ready.push_front(dependent);
                        }
                    }
                }
            }
        }

        assert!(
            nodes_completed.len() == self.graph.nodes.len(),
            "Cycle detected in system dependencies"
        );
    }
    pub fn schedule<Ty: Provider>(mut self, sequence: impl Sequence<Ty>) -> Self {
        sequence.transform(&mut self.graph);
        self
    }
}
