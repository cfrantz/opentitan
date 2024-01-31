use crate::io::uart::Uart;
use anyhow::Result;
use std::io::{Read, Write};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum XmodemError {
    #[error("Cancelled")]
    Cancelled,
    #[error("Exhausted retries: {0}")]
    ExhaustedRetries(usize),
    #[error("Unsupported mode: {0}")]
    UnsupportedMode(String),
}

#[derive(Debug)]
pub struct Xmodem {
    pub max_errors: usize,
    pub pad_byte: u8,
    pub block_len: usize,
}

impl Default for Xmodem {
    fn default() -> Self {
        Self::new()
    }
}

impl Xmodem {
    const POLYNOMIAL: u16 = 0x1021;
    const CRC: u8 = 0x43;
    const SOH: u8 = 0x01;
    const STX: u8 = 0x02;
    const EOF: u8 = 0x04;
    const ACK: u8 = 0x06;
    const NAK: u8 = 0x15;
    const CAN: u8 = 0x18;

    pub fn new() -> Self {
        Xmodem {
            max_errors: 16,
            pad_byte: 0xff,
            block_len: 1024,
        }
    }

    fn crc16(buf: &[u8]) -> u16 {
        let mut crc = 0u16;
        for byte in buf {
            crc ^= (*byte as u16) << 8;
            for _bit in 0..8 {
                let msb = crc & 0x8000 != 0;
                crc <<= 1;
                if msb {
                    crc ^= Self::POLYNOMIAL;
                }
            }
        }
        crc
    }

    pub fn send(&self, uart: &dyn Uart, data: impl Read) -> Result<()> {
        self.send_start(uart)?;
        self.send_data(uart, data)?;
        self.send_finish(uart)?;
        Ok(())
    }

    fn send_start(&self, uart: &dyn Uart) -> Result<()> {
        let mut ch = 0u8;
        let mut cancels = 0usize;
        // Wait for the XMODEM CRC start sequence.
        loop {
            uart.read(std::slice::from_mut(&mut ch))?;
            match ch {
                Self::CRC => {
                    return Ok(());
                }
                Self::NAK => {
                    return Err(XmodemError::UnsupportedMode("standard checksums".into()).into());
                }
                Self::CAN => {
                    cancels += 1;
                    if cancels >= 2 {
                        return Err(XmodemError::Cancelled.into());
                    }
                }
                _ => {
                    log::info!("Unknown byte received while waiting for XMODEM start: {ch:#x?}");
                }
            }
        }
    }

    fn send_data(&self, uart: &dyn Uart, mut data: impl Read) -> Result<()> {
        let mut block = 0usize;
        let mut errors = 0usize;
        loop {
            block += 1;
            let mut buf = vec![self.pad_byte; self.block_len + 3];
            let n = data.read(&mut buf[3..])?;
            if n == 0 {
                break;
            }

            buf[0] = match self.block_len {
                128 => Self::SOH,
                1024 => Self::STX,
                _ => {
                    return Err(XmodemError::UnsupportedMode(format!(
                        "block_len {}",
                        self.block_len
                    ))
                    .into());
                }
            };
            buf[1] = block as u8;
            buf[2] = 255 - buf[1];
            let crc = Self::crc16(&buf[3..]);
            buf.push((crc >> 8) as u8);
            buf.push((crc & 0xFF) as u8);
            log::info!("Sending block {block}");

            let mut cancels = 0usize;
            loop {
                uart.write(&buf)?;
                let mut ch = 0u8;
                uart.read(std::slice::from_mut(&mut ch))?;
                match ch {
                    Self::ACK => break,
                    Self::NAK => {
                        log::info!("XMODEM send got NAK.  Retrying.");
                        errors += 1;
                    }
                    Self::CAN => {
                        cancels += 1;
                        if cancels >= 2 {
                            return Err(XmodemError::Cancelled.into());
                        }
                    }
                    _ => {
                        log::info!("Expected ACK. Got {ch:#x}.");
                        errors += 1;
                    }
                }
                if errors > self.max_errors {
                    return Err(XmodemError::ExhaustedRetries(errors).into());
                }
            }
        }
        Ok(())
    }

    fn send_finish(&self, uart: &dyn Uart) -> Result<()> {
        uart.write(&[Self::EOF])?;
        let mut ch = 0u8;
        uart.read(std::slice::from_mut(&mut ch))?;
        if ch != Self::ACK {
            log::info!("Expected ACK. Got {ch:#x}.");
        }
        Ok(())
    }

    pub fn receive(&self, uart: &dyn Uart, data: &mut impl Write) -> Result<()> {
        // Send the byte indicating the protocol we want (Xmodem-CRC).
        uart.write(&[Self::CRC])?;

        let mut block = 1u8;
        let mut errors = 0usize;
        loop {
            // The first byte of the packet is the packet type which indicates the block size.
            let mut byte = 0u8;
            uart.read(std::slice::from_mut(&mut byte))?;
            let block_len = match byte {
                Self::SOH => 128,
                Self::STX => 1024,
                Self::EOF => {
                    // End of file.  Send an ACK.
                    uart.write(&[Self::ACK])?;
                    break;
                },
                _ => {
                    return Err(XmodemError::UnsupportedMode(format!(
                            "bad start of packet: {byte:?}")).into());
                }
            };

            // The next two bytes are the block number and its complement.
            let mut bnum = 0u8;
            let mut bcom = 0u8;
            uart.read(std::slice::from_mut(&mut bnum))?;
            uart.read(std::slice::from_mut(&mut bcom))?;
            let cancel = block != bnum || bnum != 255-bcom;

            // The next `block_len` bytes are the packet itself.
            let mut buffer = Vec::new();
            buffer.resize(block_len, 0);
            let mut total = 0;
            while total < block_len {
                let n = uart.read(&mut buffer[total..])?;
                total += n;
            }

            // The final two bytes are the CRC16.
            let mut crc1 = 0u8;
            let mut crc2 = 0u8;
            uart.read(std::slice::from_mut(&mut crc1))?;
            uart.read(std::slice::from_mut(&mut crc2))?;
            let crc = u16::from_be_bytes([crc1, crc2]);

            // If we should cancel, do it now.
            if cancel {
                uart.write(&[Self::CAN, Self::CAN])?;
                return Err(XmodemError::Cancelled.into());
            }
            if Self::crc16(&buffer) == crc {
                // CRC was good; send an ACK and keep the data.
                uart.write(&[Self::ACK])?;
                data.write(&buffer)?;
                block = block.wrapping_add(1);
            } else {
                uart.write(&[Self::NAK])?;
                errors+=1;
            }
            if errors > self.max_errors {
                return Err(XmodemError::ExhaustedRetries(errors).into());
            }
        }
        Ok(())
    }
}
