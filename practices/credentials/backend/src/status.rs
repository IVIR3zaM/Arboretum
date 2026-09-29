//! Revocation through status lists.
//!
//! Each issuer publishes one bitstring. Every credential it issues carries an
//! index into that bitstring (`credentialStatus.statusListIndex`); the
//! credential is revoked when the bit at that index is 1. Bit 0 is the
//! most significant bit of the first byte.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use thiserror::Error;

use crate::store::Store;

/// Bits per list: large enough that an index says little about when a
/// credential was issued.
pub const DEFAULT_CAPACITY: usize = 131_072;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StatusList {
    bits: Vec<u8>,
    capacity: usize,
    allocated: usize,
}

impl StatusList {
    pub fn new(capacity: usize) -> Self {
        StatusList { bits: vec![0; capacity.div_ceil(8)], capacity, allocated: 0 }
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    /// Reserves the next unused index, or `None` once the list is full.
    pub fn allocate(&mut self) -> Option<usize> {
        if self.allocated >= self.capacity {
            return None;
        }
        self.allocated += 1;
        Some(self.allocated)
    }

    pub fn set(&mut self, index: usize, revoked: bool) {
        let mask = 0x80u8 >> (index % 8);
        if let Some(byte) = self.bits.get_mut(index / 8) {
            if revoked {
                *byte |= mask;
            } else {
                *byte &= !mask;
            }
        }
    }

    pub fn is_set(&self, index: usize) -> bool {
        let mask = 0x80u8 >> (index % 8);
        self.bits.get(index / 8).is_some_and(|byte| byte & mask != 0)
    }

    /// The published form of the list: base64url of the bitstring.
    pub fn encode(&self) -> String {
        URL_SAFE_NO_PAD.encode(&self.bits)
    }

    pub fn decode(encoded: &str, capacity: usize) -> Option<Self> {
        let bits = URL_SAFE_NO_PAD.decode(encoded).ok()?;
        (bits.len() == capacity.div_ceil(8)).then_some(StatusList { bits, capacity, allocated: capacity })
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum StatusError {
    #[error("no credential {0}")]
    UnknownCredential(String),
    #[error("no status list {0}")]
    UnknownList(String),
}

/// What changed when a credential's status flipped.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StatusChange {
    pub credential_id: String,
    pub issuer: String,
    pub status_list: String,
    pub status_index: usize,
    pub revoked: bool,
}

/// Revokes an issued credential by setting its bit in its issuer's list.
pub fn revoke_credential(store: &Store, credential_id: &str) -> Result<StatusChange, StatusError> {
    let record = store
        .credential(credential_id)
        .ok_or_else(|| StatusError::UnknownCredential(credential_id.to_string()))?;
    if !store.set_status(&record.status_list, record.status_index, true) {
        return Err(StatusError::UnknownList(record.status_list));
    }
    Ok(StatusChange {
        credential_id: record.id,
        issuer: record.issuer,
        status_list: record.status_list,
        status_index: record.status_index,
        revoked: true,
    })
}
