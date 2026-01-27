use std::sync::Mutex;
use shared_memory::*;
use std::slice;
use std::sync::LazyLock;

pub struct ShmemManager {
    shmem: Shmem,
}
unsafe impl Send for ShmemManager {}
unsafe impl Sync for ShmemManager {}

impl ShmemManager {
    pub fn new(path: &str, size: usize) -> Result<Self, Box<dyn std::error::Error>> {
        let shmem = match ShmemConf::new().os_id(path).open() {
            Ok(m) => m,
            Err(_) => {
                ShmemConf::new().size(size).os_id(path).create()?
            }
        };
        Ok(Self { shmem })
    }

    pub fn write_data(&self, air: &[u8], slider: &[u8]) {
        let len = self.shmem.len();
        let ptr = self.shmem.as_ptr();
        let data_slice = unsafe { slice::from_raw_parts_mut(ptr, len) };

        if air.len() >= 6 && data_slice.len() >= 6 {
            data_slice[0..6].copy_from_slice(&air[0..6]);
        }
        if slider.len() >= 32 && data_slice.len() >= 38 {
            data_slice[6..38].copy_from_slice(&slider[0..32]);
        }
    }

    pub fn write_status(&self, coin: u8, service: u8, test: u8) {
        let len = self.shmem.len();
        let ptr = self.shmem.as_ptr();
        let data_slice = unsafe { slice::from_raw_parts_mut(ptr, len) };

        if data_slice.len() < 137 { return; }
        data_slice[134] = test;
        data_slice[135] = service;
        data_slice[136] = coin;
    }

    pub fn write_card_raw(&self, raw_bcd: &[u8]) {
        let len = self.shmem.len();
        let ptr = self.shmem.as_ptr();
        let data_slice = unsafe { slice::from_raw_parts_mut(ptr, len) };
        if data_slice.len() < 150 { return; }
        let is_empty = raw_bcd.is_empty() || raw_bcd.iter().all(|&x| x == 0);

        if is_empty {
            data_slice[138] = 0;
            data_slice[140..150].fill(0);
        } else {
            let copy_len = std::cmp::min(raw_bcd.len(), 10);
            data_slice[140..140 + copy_len].copy_from_slice(&raw_bcd[..copy_len]);
            data_slice[138] = 1;
        }
    }
}

pub static GLOBAL_SHMEM: LazyLock<Mutex<Option<ShmemManager>>> = LazyLock::new(|| {
    Mutex::new(None)
});

pub fn init_shmem() -> Result<(), String> {
    let mut lock = GLOBAL_SHMEM.lock().map_err(|_| "Failed to lock GLOBAL_SHMEM")?;
    if lock.is_none() {
        match ShmemManager::new("RustnithmSharedMemory", 1024) {
            Ok(manager) => {
                manager.write_card_raw(&[]);
                *lock = Some(manager);
                Ok(())
            }
            Err(e) => Err(format!("Shmem Init Error: {}", e)),
        }
    } else {
        Ok(())
    }
}