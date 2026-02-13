use crate::SERVER_INSTANCE;
use crate::shmem::GLOBAL_SHMEM;
pub use crate::frb_generated::StreamSink;
use std::sync::{RwLock, LazyLock};
use std::net::SocketAddr;
use crate::protocol::HandshakePayload;

pub struct SensorData {
    pub air: Vec<u8>,
    pub slider: Vec<u8>,
    pub coin: u8,
    pub service: u8,
    pub test: u8,
    pub code: [u8; 10],
}

pub static SENSOR_SINK: LazyLock<RwLock<Option<StreamSink<SensorData>>>> = LazyLock::new(|| {
    RwLock::new(None)
});

pub fn create_sensor_stream(sink: StreamSink<SensorData>) {
    if let Ok(mut guard) = SENSOR_SINK.write() {
        *guard = Some(sink);
    }
}

pub fn init_last_ip(ip: String) {
    if let Ok(addr) = ip.parse::<SocketAddr>() {
        if let Ok(lock) = SERVER_INSTANCE.lock() {
            if let Ok(mut addr_guard) = lock.last_client_addr.lock() {
                *addr_guard = Some(addr);
            }
        }
    }
}

pub fn toggle_server(port: u16, _is_udp: bool) -> bool {
    let _ = crate::shmem::init_shmem();
    match SERVER_INSTANCE.lock() {
        Ok(lock) => {
            if lock.is_running_status() {
                lock.stop();
                lock.set_active(false);
                true
            } else {
                lock.set_active(true);
                lock.start(port);
                true
            }
        }
        Err(_) => false,
    }
}
pub fn handle_handshake(incoming: HandshakePayload) {
    if let Ok(server) = SERVER_INSTANCE.lock() {
        if !server.is_running_status() { return; }

        let current_s = server.is_active_status();
        let new_state = incoming.client_target;
        if new_state != current_s {
            server.set_active(new_state);
            report_to_flutter(vec![0; 6], vec![0; 32], 0, 0, 0, [0u8; 10]);
        }

        let response = HandshakePayload {
            client_current: incoming.client_current,
            server_current: new_state,
            client_target: incoming.client_target,
            server_target: new_state,
        };
        server.send_handshake(response);
    }
}

pub fn toggle_sync() -> bool {
    match SERVER_INSTANCE.lock() {
        Ok(lock) => {
            if !lock.is_running_status() {
                return false;
            }
            let current_active = lock.is_active_status();
            let next_state = !current_active;

            let payload = HandshakePayload {
                client_current: false,
                server_current: current_active,
                client_target: next_state,
                server_target: next_state,
            };
            lock.send_handshake(payload)
        }
        Err(_) => false,
    }
}

pub fn sync_to_shmem(
    air: Vec<u8>,
    slider: Vec<u8>,
    coin: u8,
    service: u8,
    test: u8,
) {
    if let Ok(lock) = GLOBAL_SHMEM.lock() {
        if let Some(manager) = lock.as_ref() {
            manager.write_data(&air, &slider);
            manager.write_status(coin, service, test);
        }
    }
}

pub fn report_to_flutter(
    air: Vec<u8>,
    slider: Vec<u8>,
    coin: u8,
    service: u8,
    test: u8,
    code: [u8; 10],
) {
    if let Ok(guard) = SENSOR_SINK.read() {
        if let Some(sink) = guard.as_ref() {
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