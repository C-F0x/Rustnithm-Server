#[derive(PartialEq, Clone, Copy, Debug)]
pub enum PacketType {
    Handshake = 0b00,
    Button = 0b01,
    Control = 0b10,
    Card = 0b11,
}

pub struct PacketHeader {
    pub is_tcp: bool,
    pub is_server: bool,
    pub packet_type: PacketType,
}

pub struct HandshakePayload {
    pub client_current: bool,
    pub server_current: bool,
    pub client_target: bool,
    pub server_target: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ToggleOpcode { Request = 1, Response = 2 }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ToggleResult { None = 0, Done = 1, Already = 2, Fail = 3, Clash = 4 }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ToggleFrame {
    pub opcode: ToggleOpcode,
    pub target: bool,
    pub request_id: u32,
    pub result: ToggleResult,
}

pub struct ControlPayload {
    pub air: [u8; 6],
    pub slider: [u8; 32],
}

pub struct ProtocolParser;

impl ProtocolParser {
    pub fn parse_header(header: u8) -> Option<PacketHeader> {
        let is_tcp = (header >> 7) & 1 == 1;
        let is_server = (header >> 6) & 1 == 1;
        let type_bits = (header >> 4) & 0b11;

        let packet_type = match type_bits {
            0b00 => Some(PacketType::Handshake),
            0b01 => Some(PacketType::Button),
            0b10 => Some(PacketType::Control),
            0b11 => Some(PacketType::Card),
            _ => None,
        }?;

        Some(PacketHeader {
            is_tcp,
            is_server,
            packet_type,
        })
    }

    pub fn parse_handshake(payload_byte: u8) -> HandshakePayload {
        HandshakePayload {
            client_current: (payload_byte >> 7) & 1 == 1,
            server_current: (payload_byte >> 6) & 1 == 1,
            client_target: (payload_byte >> 5) & 1 == 1,
            server_target: (payload_byte >> 4) & 1 == 1,
        }
    }

    pub fn parse_toggle(payload: &[u8]) -> Option<ToggleFrame> {
        if payload.len() < 7 { return None; }
        let opcode = match payload[0] { 1 => ToggleOpcode::Request, 2 => ToggleOpcode::Response, _ => return None };
        let target = payload[1] != 0;
        let request_id = u32::from_le_bytes([payload[2], payload[3], payload[4], payload[5]]);
        let result = match payload.get(6).copied().unwrap_or(0) {
            0 => ToggleResult::None,
            1 => ToggleResult::Done,
            2 => ToggleResult::Already,
            3 => ToggleResult::Fail,
            4 => ToggleResult::Clash,
            _ => return None,
        };
        Some(ToggleFrame { opcode, target, request_id, result })
    }

    pub fn build_toggle(header: u8, frame: ToggleFrame) -> Vec<u8> {
        vec![
            header,
            frame.opcode as u8,
            frame.target as u8,
            (frame.request_id & 0xff) as u8,
            ((frame.request_id >> 8) & 0xff) as u8,
            ((frame.request_id >> 16) & 0xff) as u8,
            ((frame.request_id >> 24) & 0xff) as u8,
            frame.result as u8,
        ]
    }

    pub fn build_handshake_response(
        client_current: bool,
        server_current: bool,
        client_target: bool,
        server_target: bool
    ) -> [u8; 2] {
        let header = 0b0100_0000;
        let mut payload = 0u8;
        if client_current { payload |= 1 << 7; }
        if server_current { payload |= 1 << 6; }
        if client_target  { payload |= 1 << 5; }
        if server_target  { payload |= 1 << 4; }
        [header, payload]
    }

    pub fn parse_control(payload: &[u8]) -> Option<ControlPayload> {
        if payload.len() < 5 { return None; }
        let mut air = [0u8; 6];
        let air_byte = payload[0];
        for i in 0..6 {
            air[i] = if (air_byte & (1 << i)) != 0 { 1 } else { 0 };
        }
        let mut slider = [0u8; 32];
        for byte_idx in 0..4 {
            let current_byte = payload[byte_idx + 1];
            for bit_idx in 0..8 {
                let global_idx = byte_idx * 8 + bit_idx;
                slider[global_idx] = if (current_byte & (1 << bit_idx)) != 0 { 1 } else { 0 };
            }
        }
        Some(ControlPayload { air, slider })
    }
    pub fn parse_card(payload: &[u8]) -> Option<[u8; 10]> {
        if payload.len() < 10 { return None; }
        let mut code = [0u8; 10];
        code.copy_from_slice(&payload[..10]);
        Some(code)
    }
}
