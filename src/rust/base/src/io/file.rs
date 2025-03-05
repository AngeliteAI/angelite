use crate::ffi;

pub struct File(ffi::File);

impl File {
    fn open(path: Path) -> Self {}

    fn create(path: Path) -> Self {}

    fn close(self) {}
}
