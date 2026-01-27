#[derive(PartialEq, Clone, Copy, Debug)]
pub enum PacketType {
    Heartbeat = 0b00,
    Button = 0b01,
    Control = 0b10,
    Card = 0b11,
}

pub struct ControlPayload {
    pub air: [u8; 6],
    pub slider: [u8; 32],
}

pub struct ProtocolParser;

impl ProtocolParser {
    pub fn get_type(header: u8) -> Option<PacketType> {
        match (header >> 4) & 0b11 {
            0b00 => Some(PacketType::Heartbeat),
            0b01 => Some(PacketType::Button),
            0b10 => Some(PacketType::Control),
            0b11 => Some(PacketType::Card),
            _ => None,
        }
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
                slider[global_idx] = if (current_byte & (1 << (7 - bit_idx))) != 0 { 1 } else { 0 };
            }
        }

        Some(ControlPayload { air, slider })
    }
    pub fn parse_card(payload: &[u8]) -> Option<[u8; 20]> {
        if payload.len() < 10 { return None; }

        let mut code = [0u8; 20];
        for i in 0..10 {
            let byte = payload[i];
            let high = (byte >> 4) & 0x0F;
            let low = byte & 0x0F;

            code[i * 2] = high;
            code[i * 2 + 1] = low;
        }

        Some(code)
    }
}