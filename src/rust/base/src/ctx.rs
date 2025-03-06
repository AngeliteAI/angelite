use std::{
    mem::{self, MaybeUninit},
    sync::atomic::{self, AtomicBool},
};

use crate::{
    bindings::{self},
    io::{
        self, Completion, Operation, OperationId,
        file::File,
        net::{Connection, Listener, Socket},
    },
};

pub static INIT: AtomicBool = AtomicBool::new(false);

pub struct Context(*mut bindings::Context);

pub enum HandleType {
    File,
    Socket,
    Listener,
    Connection,
}

impl HandleType {
    fn from_raw(ptr: *mut ()) {
        match unsafe { bindings::handleType(ptr as *mut _).unwrap().read() } {
            bindings::HandleType::File => todo!(),
            bindings::HandleType::Socket => {
                let info = todo!(); //bindings::socketInfo(ffi.op.handle as *mut _);
            }
        }
    }
}

impl Context {
    fn current() -> Context {
        if !INIT.load(atomic::Ordering::Relaxed) {
            unsafe {
                bindings::init(14);
            }
        }
        Context(unsafe { bindings::current().unwrap() })
    }

    fn submit(&self) {
        unsafe { bindings::submit() };
    }

    fn poll(&self) -> Vec<(Operation, Completion)> {
        let mut complete = vec![];

        loop {
            let mut potential = Vec::<bindings::Complete>::new();
            potential.reserve_exact(1000);

            let mut completed = unsafe { bindings::poll(potential.as_mut_ptr(), 1000) };

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
            .map(|bindings| unsafe {
                (
                    io::Operation {
                        id: OperationId(bindings.op.id),
                        ty: mem::transmute(bindings.op.type_),
                        handle: todo!(),
                        user_data: bindings.op.user_data as _,
                    },
                    io::Completion(bindings.result),
                )
            })
            .collect()
    }
}
