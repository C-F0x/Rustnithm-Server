use crate::SERVER_INSTANCE;
use crate::server::ServerConfig;
use crate::shmem::GLOBAL_SHMEM;
pub use crate::frb_generated::StreamSink;

pub struct SensorData {
    pub air: Vec<u8>,
    pub slider: Vec<u8>,
    pub coin: u8,
    pub service: u8,
    pub test: u8,
    pub code: String,
}

lazy_static! {
    pub static ref SENSOR_SINK: std::sync::RwLock<Option<StreamSink<SensorData>>> = std::sync::RwLock::new(None);
}

pub fn create_sensor_stream(sink: StreamSink<SensorData>) {
    if let Ok(mut guard) = std::sync::RwLock::write(&SENSOR_SINK) {
        *guard = Some(sink);
    }
}

pub fn start_server(port: u16, is_udp: bool) -> String {
    crate::init_native_backend();
    {
        let lock = SERVER_INSTANCE.lock().expect("Lock failed");
        lock.start(ServerConfig {
            port,
            protocol: if is_udp { "udp".into() } else { "tcp".into() },
        });
    }
    "SUCCESS".into()
}

pub fn stop_server() -> bool {
    if let Ok(lock) = SERVER_INSTANCE.try_lock() {
        lock.stop();
    }
    if let Ok(mut guard) = std::sync::RwLock::write(&SENSOR_SINK) {
        *guard = None;
    }
    true
}

pub fn report_to_flutter(air: Vec<u8>, slider: Vec<u8>, coin: u8, service: u8, test: u8, code: String) {
    if let Ok(guard) = std::sync::RwLock::read(&SENSOR_SINK) {
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

pub fn sync_to_shmem(air: Vec<u8>, slider: Vec<u8>, coin: u8, service: u8, test: u8, code: String) {
    if let Ok(mut lock) = GLOBAL_SHMEM.lock() {
        if let Some(shmem) = lock.as_mut() {
            shmem.write_data(&air, &slider);
            shmem.write_aux(coin, service, test, &code);
        }
    }
}