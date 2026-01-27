mod frb_generated;

pub mod api;
pub mod server;
pub mod shmem;
pub mod protocol;

use crate::server::SensorServer;
use std::sync::{Mutex, LazyLock};

pub static SERVER_INSTANCE: LazyLock<Mutex<SensorServer>> = LazyLock::new(|| {
    Mutex::new(SensorServer::new())
});

pub fn init_native_backend() -> Result<(), String> {
    shmem::init_shmem()
}