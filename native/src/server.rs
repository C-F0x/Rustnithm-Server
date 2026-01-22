use std::net::UdpSocket;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use crate::protocol::{ProtocolParser, PacketType};
use crate::shmem::GLOBAL_SHMEM;
use crate::api::{report_to_flutter, send_log};

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
            is_running: Arc::new(AtomicBool::new(false))
        }
    }

    pub fn start(&self, config: ServerConfig) {
        let is_running = self.is_running.clone();
        if is_running.load(Ordering::SeqCst) { return; }

        is_running.store(true, Ordering::SeqCst);

        thread::spawn(move || {
            let addr = format!("0.0.0.0:{}", config.port);
            let socket = match UdpSocket::bind(&addr) {
                Ok(s) => {
                    s.set_read_timeout(Some(Duration::from_millis(100))).ok();
                    s
                },
                Err(e) => {
                    send_log("ERROR".into(), format!("Bind failed: {}", e));
                    is_running.store(false, Ordering::SeqCst);
                    return;
                }
            };

            send_log("INFO".into(), format!("New Protocol Server (UDP) listening on {}", addr));

            let mut buf = [0u8; 1024];
            while is_running.load(Ordering::SeqCst) {
                match socket.recv_from(&mut buf) {
                    Ok((size, _)) => {
                        if size > 0 {
                            Self::handle_packet(&buf[..size]);
                        }
                    },
                    Err(e) => {
                        if e.kind() != std::io::ErrorKind::TimedOut && e.kind() != std::io::ErrorKind::WouldBlock {
                             send_log("DEBUG".into(), format!("Socket error: {:?}", e.kind()));
                        }
                    }
                }
            }

            send_log("SUCCESS".into(), "!!! SERVER THREAD EXIT !!!".into());
        });
    }

    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
    }
    fn handle_packet(data: &[u8]) {
        if data.is_empty() { return; }

        let header = data[0];
        if !ProtocolParser::verify_header(header) { return; }
        match ProtocolParser::get_type(header) {
            Some(PacketType::Control) => {
                if data.len() >= 7 {
                    if let Some(payload) = ProtocolParser::parse_control(&data[1..7]) {
                        if let Ok(lock) = GLOBAL_SHMEM.lock() {
                                                if let Some(manager) = lock.as_ref() {
                                                    manager.write_data(&payload.air, &payload.slider);
                                                }
                                            }
                        report_to_flutter(
                            payload.air.to_vec(),
                            payload.slider.to_vec(),
                            0, 0, 0
                        );
                    }
                }
            },

            _ => {}
        }
    }
}