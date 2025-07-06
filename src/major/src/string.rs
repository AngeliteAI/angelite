pub const SIZE: usize = 8192;

#[repr(C)]
pub struct String<const N: usize = { SIZE }> {
    pub(crate) data: [u8; N],
    pub(crate) null_terminator: u8,
}

impl<const N: usize> String<N> {
    pub fn new() -> Self {
        Self {
            data: [0; N],
            null_terminator: 0,
        }
    }

    pub fn as_ptr(&self) -> *const u8 {
        self.data.as_ptr()
    }

    pub fn as_mut_ptr(&mut self) -> *mut u8 {
        self.data.as_mut_ptr()
    }

    pub fn len(&self) -> usize {
        self.data.iter().take_while(|&&c| c != 0).count()
    }
}

impl<const N: usize> core::fmt::Display for String<N> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        let len = self.len();
        let slice = &self.data[..len];
        match core::str::from_utf8(slice) {
            Ok(s) => write!(f, "{}", s),
            Err(_) => write!(f, "<invalid utf8>"),
        }
    }
}
