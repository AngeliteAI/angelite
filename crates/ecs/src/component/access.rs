use super::{Handle, Meta};

pub trait Access: ?Sized {
    fn access<'a>(ptr: *const u8, vtable: *const ()) -> &'a mut Self;
    fn meta() -> Meta;
}
