use std::{net::IpAddr, path::PathBuf};

use clap::Parser;

const VERSION: &str = env!("CARGO_PKG_VERSION");
const ABOUT: &str = env!("CARGO_PKG_DESCRIPTION");

#[derive(Parser, Debug)]
#[command(version = VERSION, about = Some(ABOUT), long_about = None)]
enum Args {
    Bootstrap {
        /// The port to listen on;
        /// port forwarding is required for bootstrap functionality across internet connections.
        port: u16,
    },
    Join {
        /// The IP address to connect to, including the port
        addr: IpAddr,
    },
}

pub trait Vpn {
    
}

fn main() {
    let args = Args::parse();

}
