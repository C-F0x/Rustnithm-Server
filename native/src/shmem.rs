use std::sync::Mutex;
use shared_memory::*;

pub struct ShmemManager {
    shmem: Shmem,
}

unsafe impl Send for ShmemManager {}
unsafe impl Sync for ShmemManager {}

impl ShmemManager {
    pub fn new(path: &str, size: usize) -> Self {
        let shmem = match ShmemConf::new().os_id(path).open() {
            Ok(m) => m,
            Err(_) => {
                match ShmemConf::new().size(size).os_id(path).create() {
                    Ok(m) => m,
                    Err(e) => {
                        panic!("CRITICAL: Failed to Open or Create Shmem '{}': {:?}", path, e);
                    }
                }
            }
        };
        Self { shmem }
    }

    pub fn write_data(&self, air: &[u8], slider: &[u8]) {
        let ptr = self.shmem.as_ptr();
        unsafe {
            std::ptr::copy_nonoverlapping(air.as_ptr(), ptr, 6);
            std::ptr::copy_nonoverlapping(slider.as_ptr(), ptr.add(6), 32);
        }
    }

    pub fn write_aux(&self, coin: u8, service: u8, test: u8, code: &str) {
        let ptr = self.shmem.as_ptr();
        unsafe {
            std::ptr::write(ptr.add(134), test);
            std::ptr::write(ptr.add(135), service);
            std::ptr::write(ptr.add(136), coin);

            if code.is_empty() {
                std::ptr::write(ptr.add(138), 0);
            } else {
                let mut card_bytes = [0u8; 10];
                for i in 0..10 {
                    if i * 2 + 2 <= code.len() {
                        if let Ok(byte) = u8::from_str_radix(&code[i*2..i*2+2], 16) {
                            card_bytes[i] = byte;
                        }
                    }
                }
                std::ptr::copy_nonoverlapping(card_bytes.as_ptr(), ptr.add(140), 10);
                std::ptr::write(ptr.add(139), 0);
                std::ptr::write(ptr.add(138), 1);
            }
        }
    }
}

lazy_static! {
    pub static ref GLOBAL_SHMEM: Mutex<Option<ShmemManager>> = Mutex::new(None);
}

pub fn init_shmem() {
    let mut lock = GLOBAL_SHMEM.lock().unwrap_or_else(|e| {
        eprintln!("Warning: Shmem Mutex poisoned, recovering...");
        e.into_inner()
    });

    if lock.is_none() {
        *lock = Some(ShmemManager::new("RustnithmSharedMemory", 1024));
        println!("Shmem initialized successfully.");
    }
}