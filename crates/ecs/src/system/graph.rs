use std::{
    collections::{HashMap, HashSet, VecDeque},
    fmt,
};
use flume::Receiver;
use crate::system::func::Cmd;
use super::{
    System,
    func::{Id, Provider, Put, Wrap},
};

pub struct Node {
    pub(crate) system: System,
    pub(crate) put: Put,
    name: String,
    id: Id,
    pub(crate) rx: Receiver<Cmd>
}

unsafe impl Send for Node {}
unsafe impl Sync for Node {}

impl fmt::Debug for Node {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", &self.name)
    }
}

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
pub enum Require {
    Depend { dependent: Id, dependency: Id },
}

#[derive(Default, Debug)]
pub struct Graph {
    pub(crate) nodes: HashMap<Id, Node>,
    pub(crate) requirements: HashSet<Require>,
}

impl Graph {
    pub(crate) fn register<Input, T: Provider>(&mut self, subject: impl Wrap<Input, T>) {
        let id = subject.id();
        let name = subject.name().to_string();
        let (system, rx, put) = subject.wrap();
        let node = Node {
            name,
            id,
            system,
            put,
            rx
        };
        self.nodes.insert(id, node);
    }

    pub(crate) fn require(&mut self, require: Require) {
        self.requirements.insert(require);
    }

    pub(crate) fn dependencies(&self, dependent: &Id) -> Vec<Id> {
        self.requirements
            .iter()
            .filter_map(|require| match require {
                Require::Depend {
                    dependent: id,
                    dependency,
                } if id == dependent => Some(*dependency),
                _ => None,
            })
            .collect()
    }

    pub(crate) fn dependents(&self, dependency: &Id) -> Vec<Id> {
        self.requirements
            .iter()
            .filter_map(|require| match require {
                Require::Depend {
                    dependent,
                    dependency: id,
                } if id == dependency => Some(*dependent),
                _ => None,
            })
            .collect()
    }

    pub(crate) fn search(&self, mut action: impl FnMut(&Node)) {
        let mut nodes_all = self.nodes.keys().copied().collect::<HashSet<_>>();
        let mut nodes_visited = HashSet::new();
        let mut nodes_queue = VecDeque::new();

        for node in &nodes_all {
            if self.dependencies(node).is_empty() {
                nodes_queue.push_back(*node);
            }
        }

        while let Some(node) = nodes_queue.pop_front() {
            if nodes_visited.contains(&node) {
                continue;
            }
            nodes_visited.insert(node);
            let dependents = self.dependents(&node);
            for dependent in dependents {
                let dependencies = self.dependencies(&dependent);
                if dependencies
                    .iter()
                    .all(|dependency| nodes_all.contains(dependency))
                {
                    (action)(&self.nodes[&node]);
                    nodes_queue.push_back(dependent);
                }
            }
        }
    }
}
