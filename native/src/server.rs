use std::net::{UdpSocket, SocketAddr, TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use std::io::{Read, Write};
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
    pub tcp_writer: Arc<Mutex<Option<TcpStream>>>,
}

impl SensorServer {
    pub fn new() -> Self {
        Self {
            is_running: Arc::new(AtomicBool::new(false)),
            is_active: Arc::new(AtomicBool::new(false)),
            last_client_addr: Arc::new(Mutex::new(None)),
            socket: Arc::new(Mutex::new(None)),
            tcp_writer: Arc::new(Mutex::new(None)),
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

    pub fn start(&self, port: u16, is_tcp: bool) {
        if self.is_running.load(Ordering::SeqCst) {
            return;
        }

        self.is_running.store(true, Ordering::SeqCst);
        let is_running = self.is_running.clone();
        let is_active = self.is_active.clone();
        let last_client_addr = self.last_client_addr.clone();
        let shared_socket = self.socket.clone();
        let shared_tcp_writer = self.tcp_writer.clone();

        if is_tcp {
            thread::spawn(move || {
                let listener = match TcpListener::bind(format!("0.0.0.0:{}", port)) {
                    Ok(l) => l,
                    Err(_) => {
                        is_running.store(false, Ordering::SeqCst);
                        return;
                    }
                };
                listener.set_nonblocking(false).unwrap();

                while is_running.load(Ordering::SeqCst) {
                    match listener.accept() {
                        Ok((stream, src)) => {
                            if let Ok(mut addr_guard) = last_client_addr.lock() {
                                *addr_guard = Some(src);
                            }

                            let writer_clone = match stream.try_clone() {
                                Ok(c) => c,
                                Err(_) => continue,
                            };
                            if let Ok(mut guard) = shared_tcp_writer.lock() {
                                *guard = Some(writer_clone);
                            }

                            let is_running_inner = is_running.clone();
                            let is_active_inner = is_active.clone();

                            thread::spawn(move || {
                                handle_tcp_client(stream, is_running_inner, is_active_inner);
                            });
                        }
                        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                            thread::sleep(Duration::from_millis(10));
                        }
                        Err(_) => {
                            thread::sleep(Duration::from_millis(10));
                        }
                    }
                }

                if let Ok(mut guard) = shared_tcp_writer.lock() {
                    *guard = None;
                }
            });
        } else {
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
                let mut last_button_time: Option<Instant> = None;
                let mut last_card_time: Option<Instant> = None;
                let ttl_duration = Duration::from_millis(100);

                while is_running.load(Ordering::SeqCst) {
                    match socket.recv_from(&mut buf) {
                        Ok((amt, src)) => {
                            if amt > 0 {
                                if let Ok(mut addr_guard) = last_client_addr.lock() {
                                    *addr_guard = Some(src);
                                }
                                process_packet(
                                    &buf[..amt],
                                    &is_active,
                                    &mut last_button_time,
                                    &mut last_card_time,
                                );
                            }
                        }
                        Err(_) => {}
                    }

                    tick_ttl(&mut last_button_time, &mut last_card_time, ttl_duration);
                }

                if let Ok(mut guard) = shared_socket.lock() {
                    *guard = None;
                }
            });
        }
    }

    pub fn stop(&self) {
        self.is_running.store(false, Ordering::SeqCst);
        if let Ok(mut guard) = self.tcp_writer.lock() {
            *guard = None;
        }
    }

    pub fn send_handshake(&self, p: crate::protocol::HandshakePayload) -> bool {
        let header = 0b0100_0000u8;
        let mut payload = 0u8;
        if p.client_current { payload |= 1 << 7; }
        if p.server_current { payload |= 1 << 6; }
        if p.client_target  { payload |= 1 << 5; }
        if p.server_target  { payload |= 1 << 4; }

        if let Ok(mut tcp_guard) = self.tcp_writer.lock() {
            if let Some(stream) = tcp_guard.as_mut() {
                let frame_len = 2u16;
                let mut framed = [0u8; 4];
                framed[0..2].copy_from_slice(&frame_len.to_le_bytes());
                framed[2] = header;
                framed[3] = payload;
                return stream.write_all(&framed).is_ok();
            }
        }

        let target = if let Ok(addr_guard) = self.last_client_addr.lock() {
            *addr_guard
        } else {
            None
        };

        if let (Some(dest), Ok(socket_guard)) = (target, self.socket.lock()) {
            if let Some(socket) = socket_guard.as_ref() {
                let packet = [header, payload];
                return socket.send_to(&packet, dest).is_ok();
            }
        }

        false
    }
}

fn handle_tcp_client(
    stream: TcpStream,
    is_running: Arc<AtomicBool>,
    is_active: Arc<AtomicBool>,
) {
    stream.set_read_timeout(Some(Duration::from_millis(100))).unwrap();

    let mut raw_buf = [0u8; 1024];
    let mut reassembly: Vec<u8> = Vec::with_capacity(256);
    let mut last_button_time: Option<Instant> = None;
    let mut last_card_time: Option<Instant> = None;
    let ttl_duration = Duration::from_millis(100);

    let mut stream = stream;

    while is_running.load(Ordering::SeqCst) {
        match stream.read(&mut raw_buf) {
            Ok(0) => break,
            Ok(n) => {
                reassembly.extend_from_slice(&raw_buf[..n]);

                loop {
                    if reassembly.len() < 2 { break; }
                    let frame_len = u16::from_le_bytes([reassembly[0], reassembly[1]]) as usize;
                    if reassembly.len() < 2 + frame_len { break; }

                    let frame: Vec<u8> = reassembly[2..2 + frame_len].to_vec();
                    reassembly.drain(..2 + frame_len);

                    if !frame.is_empty() {
                        process_packet(&frame, &is_active, &mut last_button_time, &mut last_card_time);
                    }
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::TimedOut
                || e.kind() == std::io::ErrorKind::WouldBlock => {}
            Err(_) => break,
        }

        tick_ttl(&mut last_button_time, &mut last_card_time, ttl_duration);
    }
}

fn process_packet(
    raw: &[u8],
    is_active: &AtomicBool,
    last_button_time: &mut Option<Instant>,
    last_card_time: &mut Option<Instant>,
) {
    if raw.is_empty() { return; }

    let header_byte = raw[0];
    let payload = &raw[1..];

    let header = match ProtocolParser::parse_header(header_byte) {
        Some(h) => h,
        None => return,
    };

    if header.packet_type == PacketType::Handshake {
        if !payload.is_empty() {
            let incoming = ProtocolParser::parse_handshake(payload[0]);
            crate::api::handle_handshake(incoming);
        }
        return;
    }

    if !is_active.load(Ordering::SeqCst) { return; }

    match header.packet_type {
        PacketType::Button => {
            let mask = if !payload.is_empty() { payload[0] } else { 0 };
            let coin    = (mask & 0x01 != 0) as u8;
            let service = (mask & 0x02 != 0) as u8;
            let test    = (mask & 0x04 != 0) as u8;

            if coin != 0 || service != 0 || test != 0 {
                if let Ok(lock) = GLOBAL_SHMEM.lock() {
                    if let Some(manager) = lock.as_ref() {
                        manager.write_status(coin, service, test);
                    }
                }
                report_to_flutter(vec![0; 6], vec![0; 32], coin, service, test, [0u8; 10]);
                *last_button_time = Some(Instant::now());
            }
        }
        PacketType::Control => {
            if let Some(ctrl) = ProtocolParser::parse_control(payload) {
                if let Ok(lock) = GLOBAL_SHMEM.lock() {
                    if let Some(manager) = lock.as_ref() {
                        manager.write_data(&ctrl.air, &ctrl.slider);
                    }
                }
                report_to_flutter(ctrl.air.to_vec(), ctrl.slider.to_vec(), 0, 0, 0, [0u8; 10]);
            }
        }
        PacketType::Card => {
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
                *last_card_time = Some(Instant::now());
            }
        }
        _ => {}
    }
}

fn tick_ttl(
    last_button_time: &mut Option<Instant>,
    last_card_time: &mut Option<Instant>,
    ttl_duration: Duration,
) {
    if let Some(time) = *last_button_time {
        if time.elapsed() >= ttl_duration {
            if let Ok(lock) = GLOBAL_SHMEM.lock() {
                if let Some(manager) = lock.as_ref() {
                    manager.write_status(0, 0, 0);
                }
            }
            report_to_flutter(vec![0; 6], vec![0; 32], 0, 0, 0, [0u8; 10]);
            *last_button_time = None;
        }
    }

    if let Some(time) = *last_card_time {
        if time.elapsed() >= ttl_duration {
            if let Ok(lock) = GLOBAL_SHMEM.lock() {
                if let Some(manager) = lock.as_ref() {
                    manager.write_card_raw(&[]);
                }
            }
            report_to_flutter(vec![0; 6], vec![0; 32], 0, 0, 0, [0u8; 10]);
            *last_card_time = None;
        }
    }
}