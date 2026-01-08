use shared_memory::*;
use std::sync::Mutex;
use lazy_static::lazy_static;

const SHMEM_ID: &str = "RustnithmSharedMemory";
const SHMEM_SIZE: usize = 1024;

pub struct ShmemManager {
    shmem: Shmem
}

unsafe impl Send for ShmemManager {}
unsafe impl Sync for ShmemManager {}

impl ShmemManager {
    pub fn new() -> Self {
        let shmem = ShmemConf::new()
            .size(SHMEM_SIZE)
            .os_id(SHMEM_ID)
            .create()
            .unwrap_or_else(|_| {
                ShmemConf::new()
                    .os_id(SHMEM_ID)
                    .open()
                    .expect("Failed to open shared memory")
            });

        ShmemManager { shmem }
    }

    pub fn write_data(&self, air: &[u8], slider: &[u8]) {
        let ptr = self.shmem.as_ptr();
        unsafe {
            std::ptr::copy_nonoverlapping(air.as_ptr(), ptr, 6);
            std::ptr::copy_nonoverlapping(slider.as_ptr(), ptr.add(10), 32);
        }
    }

    pub fn write_aux(&self, coin: u8, service: u8, test: u8) {
        let ptr = self.shmem.as_ptr();
        unsafe {
            std::ptr::write(ptr.add(42), coin);
            std::ptr::write(ptr.add(43), service);
            std::ptr::write(ptr.add(44), test);
        }
    }
}

lazy_static! {
    pub static ref GLOBAL_SHMEM: Mutex<Option<ShmemManager>> = Mutex::new(None);
}

pub fn init_shmem() {
    let mut lock = GLOBAL_SHMEM.lock().unwrap();
    if lock.is_none() {
        *lock = Some(ShmemManager::new());
    }
}

pub fn deinit_shmem() {
    let mut lock = GLOBAL_SHMEM.lock().unwrap();
    *lock = None;
}