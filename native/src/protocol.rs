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