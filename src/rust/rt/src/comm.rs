use super::task::Task;

#[derive(Debug)]
pub enum Operation {
    Run(Task),
}

pub enum Intent {
    Schedule(Task),
}
