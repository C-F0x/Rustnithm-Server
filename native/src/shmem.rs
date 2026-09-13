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
        let shmem = {
            #[cfg(windows)]
            {
                Self::open_windows_mapping(path, size)?
            }
            #[cfg(not(windows))]
            {
                match ShmemConf::new().os_id(path).open() {
                    Ok(m) => m,
                    Err(_) => ShmemConf::new().size(size).os_id(path).create()?,
                }
            }
        };
        Ok(Self { shmem })
    }

    #[cfg(windows)]
    fn open_windows_mapping(
        path: &str,
        size: usize,
    ) -> Result<Shmem, Box<dyn std::error::Error>> {
        let local_path = format!("Local\\{path}");
        let open_raw = |mapping_name: &str| {
            ShmemConf::new()
                .os_id(mapping_name)
                .allow_raw(true)
                .open()
        };

        // A previous shared_memory-rs owner can leave its temp sidecar behind.
        // While that file exists, the crate attempts to open a file-backed map
        // and never reaches its raw OpenFileMappingW fallback. Move the stale
        // sidecar aside so the IO-created native mapping can be opened.
        let mut sidecar = std::env::temp_dir();
        sidecar.push("shared_memory-rs");
        sidecar.push(path.trim_start_matches('/'));
        let backup = sidecar.with_extension(format!("stale-{}", std::process::id()));
        let moved_sidecar = sidecar.exists() && std::fs::rename(&sidecar, &backup).is_ok();

        // Rustnithm-IO creates the mapping in the Local namespace. Prefer it
        // explicitly; an unprefixed mapping may exist separately and contain
        // only the server's fallback zeroed buffer.
        let raw_result = match open_raw(&local_path) {
            Ok(mapping) => Ok(mapping),
            Err(local_error) => open_raw(path).map_err(|_| local_error),
        };
        if moved_sidecar {
            if raw_result.is_ok() {
                let _ = std::fs::remove_file(&backup);
            } else {
                let _ = std::fs::rename(&backup, &sidecar);
            }
        }

        match raw_result {
            Ok(mapping) => Ok(mapping),
            Err(_) => match ShmemConf::new().os_id(path).open() {
                Ok(mapping) => Ok(mapping),
                Err(_) => Ok(ShmemConf::new().size(size).os_id(path).create()?),
            },
        }
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

    pub fn read_game_leds(&self) -> Option<(Vec<u8>, Vec<u8>, Vec<u8>)> {
        let len = self.shmem.len();
        if len < 168 { return None; }

        let ptr = self.shmem.as_ptr();
        let data = unsafe { slice::from_raw_parts(ptr, len) };

        let slider_before = data[131];
        if slider_before & 1 != 0 { return None; }
        let slider = data[38..131].to_vec();
        let slider_after = data[131];
        if slider_before != slider_after || slider_after & 1 != 0 {
            return None;
        }

        if len < 529 { return None; }
        let cabinet_before = data[528];
        if cabinet_before & 1 != 0 { return None; }
        let tower = data[150..168].to_vec();
        let billboard = data[168..528].to_vec();
        let cabinet_after = data[528];
        if cabinet_before != cabinet_after || cabinet_after & 1 != 0 {
            return None;
        }

        Some((slider, tower, billboard))
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
