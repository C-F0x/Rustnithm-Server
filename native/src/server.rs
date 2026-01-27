use std::net::UdpSocket;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
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
}

impl SensorServer {
    pub fn new() -> Self {
        Self {
            is_running: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn start(&self, config: ServerConfig) {
        let is_running = self.is_running.clone();
        if is_running.load(Ordering::SeqCst) {
            return;
        }
        is_running.store(true, Ordering::SeqCst);

        thread::spawn(move || {
            let addr = format!("0.0.0.0:{}", config.port);
            let socket = match UdpSocket::bind(&addr) {
                Ok(s) => {
                    let _ = s.set_read_timeout(Some(Duration::from_millis(100)));
                    s
                }
                Err(_) => {
                    is_running.store(false, Ordering::SeqCst);
                    return;
                }
            };

            let mut buf = [0u8; 1024];

            while is_running.load(Ordering::SeqCst) {
                match socket.recv_from(&mut buf) {
                    Ok((amt, _src)) => {
                        if amt == 0 { continue; }
                        let header = buf[0];

                        match ProtocolParser::get_type(header) {
                            Some(PacketType::Control) => {
                                if let Some(payload) = ProtocolParser::parse_control(&buf[1..amt]) {
                                    if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                        if let Some(manager) = lock.as_ref() {
                                            manager.write_data(&payload.air, &payload.slider);
                                        }
                                    }
                                    report_to_flutter(
                                        payload.air.to_vec(),
                                        payload.slider.to_vec(),
                                        0, 0, 0,
                                        [0u8; 20]
                                    );
                                }
                            }
                            Some(PacketType::Button) => {
                                if amt >= 2 {
                                    let btn_data = buf[1];
                                    let coin = if btn_data & 0x01 != 0 { 1 } else { 0 };
                                    let service = if btn_data & 0x02 != 0 { 1 } else { 0 };
                                    let test = if btn_data & 0x04 != 0 { 1 } else { 0 };

                                    if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                        if let Some(manager) = lock.as_ref() {
                                            manager.write_status(coin, service, test);
                                        }
                                    }
                                    report_to_flutter(vec![0; 6], vec![0; 32], coin, service, test, [0u8; 20]);
                                }
                            }
                            Some(PacketType::Card) => {
                                if amt >= 11 {
                                    let raw_bcd = &buf[1..11];
                                    if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                        if let Some(manager) = lock.as_ref() {
                                            manager.write_card_raw(raw_bcd);
                                        }
                                    }
                                    if let Some(decoded_code) = ProtocolParser::parse_card(raw_bcd) {
                                        report_to_flutter(
                                            vec![0; 6],
                                            vec![0; 32],
                                            0, 0, 0,
                                            decoded_code
                                        );
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                    Err(_) => {}
                }
            }
        });
    }

    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
    }
}