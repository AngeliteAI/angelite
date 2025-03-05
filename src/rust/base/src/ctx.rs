use std::{
    mem::{self, MaybeUninit},
    sync::atomic::{self, AtomicBool},
};

use crate::{
    ffi::{self, HandleType},
    io::{
        self, Completion, Operation, OperationId, file::File, net::Connection, net::Listener,
        net::Socket,
    },
};

pub static INIT: AtomicBool = AtomicBool::new(false);

pub struct Context(*mut ffi::Context);

impl Context {
    fn current() -> Context {
        if !INIT.load(atomic::Ordering::Relaxed) {
            unsafe {
                ffi::init(14);
            }
        }
        Context(unsafe { ffi::current() })
    }

    fn submit(&self) {
        unsafe { ffi::submit() };
    }

    fn poll(&self) -> Vec<(Operation, Completion)> {
        let complete = vec![];

        loop {
            let mut potential = Vec::<ffi::Complete>::new();
            potential.reserve_exact(1000);

            let mut completed = unsafe { ffi::poll(potential.as_mut_ptr(), 1000) };

            if completed == 0 {
                break;
            }

            unsafe {
                potential.set_len(completed);
            }

            complete.extend(potential);
        }

        complete
            .into_iter()
            .map(|ffi| unsafe {
                (
                    io::Operation {
                        id: OperationId(ffi.op.id),
                        ty: mem::transmute(ffi.op.type_),
                        handle: match ffi::handleType(ffi.op.handle).read() {
                            HandleType::File => File::from_raw(ffi.op.handle),
                            HandleType::Socket => Socket::from_raw(ffi.op.handle),
                        },
                        user_data: ffi.op.user_data as _,
                    },
                    io::Completion(ffi.result),
                )
            })
            .collect()
    }
}
