use std::net::UdpSocket;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

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
                    crate::api::send_log("ERROR".into(), format!("Bind failed: {}", e));
                    is_running.store(false, Ordering::SeqCst);
                    return;
                }
            };

            crate::api::send_log("INFO".into(), format!("Server listening on {}", addr));

            let mut buf = [0u8; 1024];
            while is_running.load(Ordering::SeqCst) {
                match socket.recv_from(&mut buf) {
                    Ok((size, _)) => {
                        if size == 48 {
                            Self::handle_packet(&buf[..size]);
                        }
                    },
                    Err(e) => {
                        if e.kind() != std::io::ErrorKind::TimedOut && e.kind() != std::io::ErrorKind::WouldBlock {
                             crate::api::send_log("DEBUG".into(), format!("Socket scan: {:?}", e.kind()));
                        }
                    }
                }
            }

            crate::api::send_log("SUCCESS".into(), "!!! PHYSICAL THREAD EXIT !!!".into());
        });
    }

    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
    }

    fn handle_packet(data: &[u8]) {
        let raw_air = &data[8..14];
        let raw_slider = &data[14..46];
        let coin = data[46];
        let service = if (data[47] & 0x01) != 0 { 1 } else { 0 };
        let test = if (data[47] & 0x02) != 0 { 1 } else { 0 };

        crate::api::report_to_flutter(raw_air.to_vec(), raw_slider.to_vec(), coin, service, test);
        crate::api::sync_to_shmem(raw_air.to_vec(), raw_slider.to_vec(), coin, service, test);
    }
}