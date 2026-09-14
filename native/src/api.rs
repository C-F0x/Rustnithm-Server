use crate::SERVER_INSTANCE;
use crate::shmem::GLOBAL_SHMEM;
pub use crate::frb_generated::StreamSink;
use std::sync::{RwLock, LazyLock};
use std::net::SocketAddr;
use crate::protocol::{HandshakePayload, ToggleFrame, ToggleOpcode, ToggleResult};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

pub struct SensorData {
    pub air: Vec<u8>,
    pub slider: Vec<u8>,
    pub coin: u8,
    pub service: u8,
    pub test: u8,
    pub code: [u8; 10],
}

pub struct GameLedData {
    pub slider: Vec<u8>,
    pub tower: Vec<u8>,
    pub billboard: Vec<u8>,
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
    if ip.trim().is_empty() {
        if let Ok(lock) = SERVER_INSTANCE.lock() {
            if let Ok(mut addr_guard) = lock.last_client_addr.lock() {
                *addr_guard = None;
            }
            if let Ok(mut target_guard) = lock.target_client_addr.lock() {
                *target_guard = None;
            }
        }
        return;
    }
    if let Ok(addr) = ip.parse::<SocketAddr>() {
        if let Ok(lock) = SERVER_INSTANCE.lock() {
            if let Ok(mut addr_guard) = lock.last_client_addr.lock() {
                *addr_guard = Some(addr);
            }
            if let Ok(mut target_guard) = lock.target_client_addr.lock() {
                *target_guard = Some(addr);
            }
        }
    }
}

pub fn toggle_server(port: u16, is_udp: bool) -> bool {
    if crate::shmem::init_shmem().is_err() {
        return false;
    }
    match SERVER_INSTANCE.lock() {
        Ok(lock) => {
            if lock.is_running_status() {
                lock.stop();
                lock.set_active(false);
                true
            } else {
                lock.set_active(true);
                lock.start(port, !is_udp);
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

            if lock.pending_toggle.lock().ok().map(|g| g.is_some()).unwrap_or(true) { return false; }
            let request_id = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as u32;
            if let Ok(mut pending) = lock.pending_toggle.lock() { *pending = Some((request_id, next_state, Instant::now() + std::time::Duration::from_millis(500))); }
            let sent = lock.send_toggle(ToggleFrame { opcode: ToggleOpcode::Request, target: next_state, request_id, result: ToggleResult::None });
            if !sent { if let Ok(mut pending) = lock.pending_toggle.lock() { *pending = None; } }
            sent
        }
        Err(_) => false,
    }
}

pub(crate) fn handle_toggle(
    incoming: ToggleFrame,
    udp_socket: Option<&std::net::UdpSocket>,
    source: Option<SocketAddr>,
    tcp_stream: Option<&mut std::net::TcpStream>,
) {
    let Ok(server) = SERVER_INSTANCE.lock() else { return; };
    if !server.is_running_status() { return; }
    if udp_socket.is_some() {
        if let (Some(expected), Some(actual)) = (
            server.target_client_addr.lock().ok().and_then(|g| *g),
            source,
        ) {
            if expected != actual { return; }
        }
    }
    match incoming.opcode {
        ToggleOpcode::Request => {
            let busy = server.pending_toggle.lock().ok().map(|g| g.is_some()).unwrap_or(true);
            let result = if busy {
                    if let Ok(mut pending) = server.pending_toggle.lock() { *pending = None; }
                    ToggleResult::Clash
                }
                else if server.is_active_status() == incoming.target { ToggleResult::Already }
                else { server.set_active(incoming.target); ToggleResult::Done };
            let _ = server.send_toggle_to(
                ToggleFrame {
                    opcode: ToggleOpcode::Response,
                    target: incoming.target,
                    request_id: incoming.request_id,
                    result,
                },
                tcp_stream,
            );
        }
        ToggleOpcode::Response => {
            if let Ok(mut guard) = server.pending_toggle.lock() {
                if let Some((id, target, _)) = *guard {
                    if id == incoming.request_id {
                        if incoming.result == ToggleResult::Done || incoming.result == ToggleResult::Already { server.set_active(target); }
                        *guard = None;
                    }
                }
            }
        }
    }
}

pub(crate) fn check_toggle_timeout() {
    if let Ok(server) = SERVER_INSTANCE.lock() {
        if let Ok(mut guard) = server.pending_toggle.lock() {
            if let Some((_, _, deadline)) = *guard {
                if Instant::now() >= deadline { *guard = None; }
            }
        }
    }
}

pub fn set_led_source(game: bool) {
    crate::server::LED_SOURCE_GAME.store(game, std::sync::atomic::Ordering::SeqCst);
}

pub fn set_led_send_frequency(frequency: u32) {
    crate::server::LED_SEND_HZ.store(frequency.clamp(50, 1000), std::sync::atomic::Ordering::SeqCst);
}

pub fn read_game_led_data() -> GameLedData {
    if let Ok(lock) = GLOBAL_SHMEM.lock() {
        if let Some(manager) = lock.as_ref() {
            if let Some((slider, tower, billboard)) = manager.read_game_leds() {
                return GameLedData { slider, tower, billboard };
            }
        }
    }

    GameLedData {
        slider: Vec::new(),
        tower: Vec::new(),
        billboard: Vec::new(),
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
