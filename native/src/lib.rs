mod frb_generated;

#[macro_use]
extern crate lazy_static;

pub mod api;
pub mod server;
pub mod shmem;
pub mod protocol;

use crate::server::SensorServer;
use std::sync::Mutex;

lazy_static! {
    pub static ref SERVER_INSTANCE: Mutex<SensorServer> = Mutex::new(SensorServer::new());
}
pub fn init_native_backend() {
    shmem::init_shmem();
    println!("Native Backend: Shared Memory Initialized.");
    println!("Native Backend: Protocol Dispatcher Ready.");
}