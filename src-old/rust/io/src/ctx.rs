use std::{
    mem::{self, MaybeUninit},
    sync::atomic::{self, AtomicBool},
};

use crate::{
    bindings::{
        ctx as ffi,
        file::*,
        io::{self, Complete, Operation},
        socket::*,
    },
    io::OperationId,
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
        match unsafe { io::handle_type(ptr as *mut _) } {
            io::HandleType::File => todo!(),
            io::HandleType::Socket => {
                let info = todo!(); //ffi::socketInfo(ffi.op.handle as *mut _);
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

    fn poll(&self) -> Vec<(crate::Operation, crate::Complete)> {
        let mut complete = vec![];

        loop {
            let mut potential = Vec::<io::Complete>::new();
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
            .map(|comp| unsafe {
                (
                    crate::Operation {
                        id: OperationId(comp.op.id),
                        ty: mem::transmute(comp.op.r#type),
                        handle: unsafe {
                            match comp.op.handle.cast::<io::HandleType>().read() {
                                io::HandleType::File => crate::Handle::File(
                                    crate::file::File::from_raw(comp.op.handle as *mut _),
                                ),
                                io::HandleType::Socket => crate::Handle::Socket(
                                    crate::net::Socket::from_raw(comp.op.handle as *mut _),
                                ),
                            }
                        },
                        user_data: comp.op.user_data as *mut _,
                    },
                    crate::Complete(comp.result),
                )
            })
            .collect()
    }
}
