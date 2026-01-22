use crate::SERVER_INSTANCE;
use crate::server::ServerConfig;
use crate::shmem::GLOBAL_SHMEM;
pub use crate::frb_generated::StreamSink;
use std::sync::RwLock;

pub struct SensorData {
    pub air: Vec<u8>,
    pub slider: Vec<u8>,
    pub coin: u8,
    pub service: u8,
    pub test: u8,
}

pub struct LogEntry {
    pub time: String,
    pub level: String,
    pub message: String,
}

lazy_static! {
    pub static ref SENSOR_SINK: std::sync::RwLock<Option<StreamSink<SensorData>>> = std::sync::RwLock::new(None);
    pub static ref LOG_SINK: std::sync::RwLock<Option<StreamSink<LogEntry>>> = std::sync::RwLock::new(None);
}

pub fn create_sensor_stream(sink: StreamSink<SensorData>) {
    if let Ok(mut guard) = std::sync::RwLock::write(&SENSOR_SINK) {
        *guard = Some(sink);
    }
}

pub fn create_log_stream(sink: StreamSink<LogEntry>) {
    if let Ok(mut guard) = std::sync::RwLock::write(&LOG_SINK) {
        *guard = Some(sink);
    }
    send_log("INFO".into(), "Log Stream Ready (v2)".into());
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
    send_log("SUCCESS".into(), format!("Server started on port {}", port));
    "SUCCESS".into()
}

pub fn stop_server() -> bool {
    send_log("WARN".into(), "Stop signal sent...".into());

    if let Ok(lock) = SERVER_INSTANCE.try_lock() {
        lock.stop();
    }

    if let Ok(mut guard) = std::sync::RwLock::write(&SENSOR_SINK) {
        *guard = None;
    }

    send_log("SUCCESS".into(), "Shutdown requested. Thread will exit within 100ms.".into());
    true
}

pub fn send_log(level: String, message: String) {
    if let Ok(guard) = std::sync::RwLock::read(&LOG_SINK) {
        if let Some(sink) = &*guard {
            let _ = sink.add(LogEntry {
                time: chrono::Local::now().format("%H:%M:%S").to_string(),
                level,
                message,
            });
        }
    }
}

pub fn report_to_flutter(air: Vec<u8>, slider: Vec<u8>, coin: u8, service: u8, test: u8) {
    if let Ok(guard) = std::sync::RwLock::read(&SENSOR_SINK) {
        if let Some(sink) = &*guard {
            let _ = sink.add(SensorData {
                air,
                slider,
                coin,
                service,
                test,
            });
        }
    }
}

pub fn sync_to_shmem(air: Vec<u8>, slider: Vec<u8>, coin: u8, service: u8, test: u8) {
    if let Ok(mut lock) = GLOBAL_SHMEM.lock() {
        if let Some(shmem) = lock.as_mut() {
            shmem.write_data(&air, &slider);
            shmem.write_aux(coin, service, test);
        }
    }
}