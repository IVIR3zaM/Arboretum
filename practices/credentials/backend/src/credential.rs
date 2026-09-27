//! The credential wire format: canonical JSON, Ed25519 proofs and
//! selectively disclosable claims.
//!
//! Every signature in the system covers the RFC 8785 (JCS) form of a document
//! with its `proof` member removed, so a document signed by the wallet and
//! verified here (or the other way round) hashes the same bytes on both sides.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier as _, VerifyingKey};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

pub const ED25519_SIGNATURE_2020: &str = "Ed25519Signature2020";
pub const CREDENTIALS_CONTEXT: &str = "https://www.w3.org/2018/credentials/v1";

/// One selectively disclosable claim, as handed to the holder at issuance.
///
/// The credential itself only carries [`Disclosure::digest`] in
/// `credentialSubject._sd`; the holder reveals a claim by presenting its
/// disclosure next to the credential.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Disclosure {
    pub salt: String,
    pub name: String,
    pub value: Value,
}

impl Disclosure {
    pub fn new(name: &str, value: Value) -> Self {
        Disclosure { salt: random_token(16), name: name.to_string(), value }
    }

    /// base64url (no padding) of SHA-256 over the canonical `[salt, name, value]` array.
    pub fn digest(&self) -> String {
        let triple = json!([self.salt, self.name, self.value]);
        URL_SAFE_NO_PAD.encode(Sha256::digest(canonicalize(&triple).as_bytes()))
    }
}

/// The bytes a proof signs: the canonical form of `document` without `proof`.
pub fn signing_input(document: &Value) -> Vec<u8> {
    match document {
        Value::Object(map) if map.contains_key("proof") => {
            let mut unsigned = map.clone();
            unsigned.remove("proof");
            canonicalize(&Value::Object(unsigned)).into_bytes()
        }
        other => canonicalize(other).into_bytes(),
    }
}

/// Adds (or replaces) an `Ed25519Signature2020` proof on `document`.
pub fn sign(document: &mut Value, key: &SigningKey, verification_method: &str, purpose: &str, created: i64) {
    let signature = key.sign(&signing_input(document));
    document["proof"] = json!({
        "type": ED25519_SIGNATURE_2020,
        "created": created,
        "verificationMethod": verification_method,
        "proofPurpose": purpose,
        "proofValue": affinidi_encoding::encode_base58btc(&signature.to_bytes()),
    });
}

/// Checks the `proofValue` of `document` against `key`.
pub fn verify_signature(document: &Value, key: &VerifyingKey) -> Result<(), String> {
    let proof_value = document
        .pointer("/proof/proofValue")
        .and_then(Value::as_str)
        .ok_or("proof has no proofValue")?;
    let bytes = affinidi_encoding::decode_base58btc(proof_value).map_err(|e| format!("proofValue: {e}"))?;
    let signature = Signature::from_slice(&bytes).map_err(|e| format!("proofValue: {e}"))?;
    key.verify(&signing_input(document), &signature).map_err(|_| "signature does not match".to_string())
}

/// RFC 8785 JSON Canonicalization Scheme.
///
/// Object members are ordered by the UTF-16 code units of their names,
/// strings use the minimal JSON escaping, and numbers are written the way
/// ECMAScript prints them (integral values without a fraction).
pub fn canonicalize(value: &Value) -> String {
    let mut out = String::new();
    write_canonical(value, &mut out);
    out
}

fn write_canonical(value: &Value, out: &mut String) {
    match value {
        Value::Null | Value::Bool(_) | Value::String(_) => {
            out.push_str(&serde_json::to_string(value).expect("scalars serialize"))
        }
        Value::Number(n) => out.push_str(&canonical_number(n)),
        Value::Array(items) => {
            out.push('[');
            for (i, item) in items.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                write_canonical(item, out);
            }
            out.push(']');
        }
        Value::Object(map) => {
            let mut entries: Vec<(&String, &Value)> = map.iter().collect();
            entries.sort_by(|(a, _), (b, _)| a.encode_utf16().cmp(b.encode_utf16()));
            out.push('{');
            for (i, (key, item)) in entries.into_iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                out.push_str(&serde_json::to_string(key).expect("keys serialize"));
                out.push(':');
                write_canonical(item, out);
            }
            out.push('}');
        }
    }
}

fn canonical_number(n: &serde_json::Number) -> String {
    if n.is_i64() || n.is_u64() {
        return n.to_string();
    }
    let f = n.as_f64().unwrap_or(0.0);
    if f == f.trunc() && f.abs() < 1e21 {
        format!("{}", f as i128)
    } else {
        format!("{f}")
    }
}

/// A random base64url token of `bytes` bytes of entropy.
pub fn random_token(bytes: usize) -> String {
    let mut buf = vec![0u8; bytes];
    getrandom::fill(&mut buf).expect("system randomness");
    URL_SAFE_NO_PAD.encode(buf)
}

/// A random (version 4) `urn:uuid:` identifier.
pub fn random_urn() -> String {
    let mut b = [0u8; 16];
    getrandom::fill(&mut b).expect("system randomness");
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let hex: String = b.iter().map(|x| format!("{x:02x}")).collect();
    format!("urn:uuid:{}-{}-{}-{}-{}", &hex[0..8], &hex[8..12], &hex[12..16], &hex[16..20], &hex[20..32])
}
