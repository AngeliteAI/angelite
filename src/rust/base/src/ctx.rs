use std::{
    mem::{self, MaybeUninit},
    sync::atomic::{self, AtomicBool},
};

use crate::{
    ffi::{self, HandleType, SocketType},
    io::{
        self, Completion, Operation, OperationId,
        file::File,
        net::{Connection, Listener, Socket},
    },
};

pub static INIT: AtomicBool = AtomicBool::new(false);

pub struct Context(*mut ffi::Context);

pub enum HandleType {
    File,
    Socket,
    Listener,
    Connection,
}

impl HandleType {
    fn from_raw(ptr: *mut ()) {
        match ffi::handleType(ffi.op.handle).unwrap().read() {
            HandleType::File => File::from_raw(ffi.op.handle as *mut _),
            HandleType::Socket => {
                let info = ffi::socketInfo(ffi.op.handle as *mut _);
            }
        }
    }
}

impl Context {
    fn current() -> Context {
        if !INIT.load(atomic::Ordering::Relaxed) {
            unsafe {
                ffi::init(14);
            }
        }
        Context(unsafe { ffi::current().unwrap() })
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
                        handle: todo!(),
                        user_data: ffi.op.user_data as _,
                    },
                    io::Completion(ffi.result),
                )
            })
            .collect()
    }
}
