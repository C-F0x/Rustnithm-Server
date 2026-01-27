use crate::SERVER_INSTANCE;
use crate::shmem::GLOBAL_SHMEM;
pub use crate::frb_generated::StreamSink;
use std::sync::{RwLock, LazyLock};

pub struct SensorData {
    pub air: Vec<u8>,
    pub slider: Vec<u8>,
    pub coin: u8,
    pub service: u8,
    pub test: u8,
    pub code: [u8; 20],
}

pub static SENSOR_SINK: LazyLock<RwLock<Option<StreamSink<SensorData>>>> = LazyLock::new(|| {
    RwLock::new(None)
});

pub fn create_sensor_stream(sink: StreamSink<SensorData>) {
    if let Ok(mut guard) = SENSOR_SINK.write() {
        *guard = Some(sink);
    }
}

pub fn start_server(port: u16, is_udp: bool) -> String {
    if let Err(e) = crate::shmem::init_shmem() {
        return format!("SHMEM_INIT_ERROR: {}", e);
    }

    match SERVER_INSTANCE.lock() {
        Ok(lock) => {
            lock.start(crate::server::ServerConfig {
                port,
                protocol: if is_udp { "udp".into() } else { "tcp".into() },
            });
            "SUCCESS".into()
        }
        Err(_) => "LOCK_ERROR".into(),
    }
}

pub fn stop_server() -> bool {
    if let Ok(lock) = SERVER_INSTANCE.try_lock() {
        lock.stop();
    }
    if let Ok(mut guard) = SENSOR_SINK.write() {
        *guard = None;
    }
    true
}

pub fn sync_to_shmem(
    air: Vec<u8>,
    slider: Vec<u8>,
    coin: u8,
    service: u8,
    test: u8,
    code: String
) {
    if let Ok(lock) = GLOBAL_SHMEM.lock() {
        if let Some(manager) = lock.as_ref() {
            manager.write_data(&air, &slider);
            manager.write_status(coin, service, test);
            if code.is_empty() {
                manager.write_card_raw(&[]);
            } else {
            }
        }
    }
}

pub fn report_to_flutter(
    air: Vec<u8>,
    slider: Vec<u8>,
    coin: u8,
    service: u8,
    test: u8,
    code: [u8; 20]
) {
    if let Ok(guard) = SENSOR_SINK.read() {
        if let Some(sink) = &*guard {
            let _ = sink.add(SensorData {
                air,
                slider,
                coin,
                service,
                test,
                code,
            });
        }
    }
}