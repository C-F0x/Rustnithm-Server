use std::net::{UdpSocket, SocketAddr};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use crate::protocol::{ProtocolParser, PacketType};
use crate::shmem::GLOBAL_SHMEM;
use crate::api::report_to_flutter;

pub struct ServerConfig {
    pub port: u16,
    pub protocol: String,
}

pub struct SensorServer {
    is_running: Arc<AtomicBool>,
    is_active: Arc<AtomicBool>,
    pub last_client_addr: Arc<Mutex<Option<SocketAddr>>>,
    pub socket: Arc<Mutex<Option<UdpSocket>>>,
}

impl SensorServer {
    pub fn new() -> Self {
        Self {
            is_running: Arc::new(AtomicBool::new(false)),
            is_active: Arc::new(AtomicBool::new(false)),
            last_client_addr: Arc::new(Mutex::new(None)),
            socket: Arc::new(Mutex::new(None)),
        }
    }

    pub fn set_active(&self, active: bool) {
        self.is_active.store(active, Ordering::SeqCst);
    }

    pub fn is_active_status(&self) -> bool {
        self.is_active.load(Ordering::SeqCst)
    }

    pub fn is_running_status(&self) -> bool {
        self.is_running.load(Ordering::SeqCst)
    }

    pub fn start(&self, port: u16) {
        if self.is_running.load(Ordering::SeqCst) {
            return;
        }

        self.is_running.store(true, Ordering::SeqCst);
        let is_running = self.is_running.clone();
        // 关键修改：克隆 is_active 以便在循环内部检查状态
        let is_active = self.is_active.clone();
        let last_client_addr = self.last_client_addr.clone();
        let shared_socket = self.socket.clone();

        thread::spawn(move || {
            let socket = match UdpSocket::bind(format!("0.0.0.0:{}", port)) {
                Ok(s) => s,
                Err(_) => {
                    is_running.store(false, Ordering::SeqCst);
                    return;
                }
            };

            if let Ok(s_clone) = socket.try_clone() {
                if let Ok(mut guard) = shared_socket.lock() {
                    *guard = Some(s_clone);
                }
            }

            socket.set_read_timeout(Some(Duration::from_millis(100))).unwrap();

            let mut buf = [0u8; 1024];

            while is_running.load(Ordering::SeqCst) {
                match socket.recv_from(&mut buf) {
                    Ok((amt, src)) => {
                        if let Ok(mut addr_guard) = last_client_addr.lock() {
                            *addr_guard = Some(src);
                        }

                        if amt > 0 {
                            let header_byte = buf[0];
                            if let Some(header) = ProtocolParser::parse_header(header_byte) {
                                let payload = &buf[1..amt];

                                // 逻辑修正：
                                // 1. 握手包(Handshake)无条件处理，确保能被客户端唤醒
                                if header.packet_type == PacketType::Handshake {
                                    if !payload.is_empty() {
                                        let payload_byte = payload[0];
                                        let incoming = ProtocolParser::parse_handshake(payload_byte);
                                        crate::api::handle_handshake(incoming);
                                    }
                                }
                                // 2. 其他业务包仅在 active 状态下处理
                                else if is_active.load(Ordering::SeqCst) {
                                    if header.packet_type == PacketType::Button {
                                        let mask = if !payload.is_empty() { payload[0] } else { 0 };
                                        let coin = (mask & 0x01 != 0) as u8;
                                        let service = (mask & 0x02 != 0) as u8;
                                        let test = (mask & 0x04 != 0) as u8;

                                        if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                            if let Some(manager) = lock.as_ref() {
                                                manager.write_status(coin, service, test);
                                            }
                                        }
                                        report_to_flutter(vec![0; 6], vec![0; 32], coin, service, test, [0u8; 10]);
                                    } else if header.packet_type == PacketType::Control {
                                        if let Some(ctrl) = ProtocolParser::parse_control(payload) {
                                            if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                                if let Some(manager) = lock.as_ref() {
                                                    manager.write_data(&ctrl.air, &ctrl.slider);
                                                }
                                            }
                                            report_to_flutter(ctrl.air.to_vec(), ctrl.slider.to_vec(), 0, 0, 0, [0u8; 10]);
                                        }
                                    } else if header.packet_type == PacketType::Card {
                                        if payload.len() >= 10 {
                                            let raw_bcd = &payload[0..10];
                                            if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                                if let Some(manager) = lock.as_ref() {
                                                    manager.write_card_raw(raw_bcd);
                                                }
                                            }
                                            if let Some(code) = ProtocolParser::parse_card(raw_bcd) {
                                                report_to_flutter(vec![0; 6], vec![0; 32], 0, 0, 0, code);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Err(_) => {}
                }
            }
            if let Ok(mut guard) = shared_socket.lock() {
                *guard = None;
            }
        });
    }

    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
    }

    pub fn send_handshake(&self, p: crate::protocol::HandshakePayload) -> bool {
        let target = if let Ok(addr_guard) = self.last_client_addr.lock() {
            *addr_guard
        } else {
            None
        };

        if let (Some(dest), Ok(socket_guard)) = (target, self.socket.lock()) {
            if let Some(socket) = socket_guard.as_ref() {
                let header = 0b0100_0000u8;
                let mut payload = 0u8;
                if p.client_current { payload |= 1 << 7; }
                if p.server_current { payload |= 1 << 6; }
                if p.client_target { payload |= 1 << 5; }
                if p.server_target { payload |= 1 << 4; }
                let packet = [header, payload];
                return socket.send_to(&packet, dest).is_ok();
            }
        }
        false
    }
}