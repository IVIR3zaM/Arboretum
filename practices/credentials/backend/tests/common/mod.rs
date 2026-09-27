//! Shared fixtures for the backend suite.
//!
//! Harbour Club is the issuer these tests sign with; `HARBOUR_*` are its key
//! and its published DID document. Holders are generated per test from a
//! fixed seed byte.
#![allow(dead_code)]

use std::sync::Arc;

use credentials_backend::credential::{self, Disclosure};
use credentials_backend::issuer::{CredentialRequest, IssuedCredential, Issuer};
use credentials_backend::resolver::{did_key_for, Resolver};
use credentials_backend::store::Store;
use credentials_backend::transport::StaticTransport;
use credentials_backend::verifier::{Submission, Verifier};
use ed25519_dalek::SigningKey;
use serde_json::{json, Value};

pub const HARBOUR_DID: &str = "did:web:members.harbourclub.example";
pub const HARBOUR_KEY_ID: &str = "did:web:members.harbourclub.example#key-1";
pub const HARBOUR_SEED: &str = "9f3688f6e8b93b0cfa3b11c28fbc25fe5440192ed82835e7fe3ab590f03f6c75";
pub const HARBOUR_PUBLIC: &str = "z6MkjgN85pffmWg8nS4P2epjg78ADoAaBs7jfzryUFx8vt6N";

/// 2026-06-01T00:00:00Z — "now" for every verifier in the suite.
pub const NOW: i64 = 1_780_272_000;
pub const DAY: i64 = 86_400;

pub const NONCE: &str = "n-0S6_WzA2Mj";
pub const DOMAIN: &str = "door.harbourclub.example";

pub fn seed(hex: &str) -> [u8; 32] {
    let mut out = [0u8; 32];
    for (i, byte) in out.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).unwrap();
    }
    out
}

pub fn harbour() -> Issuer {
    Issuer::new(HARBOUR_DID, HARBOUR_KEY_ID, &seed(HARBOUR_SEED))
}

pub struct Holder {
    pub key: SigningKey,
    pub did: String,
}

impl Holder {
    pub fn new(seed_byte: u8) -> Self {
        let key = SigningKey::from_bytes(&[seed_byte; 32]);
        let did = did_key_for(&key.verifying_key());
        Holder { key, did }
    }

    pub fn key_id(&self) -> String {
        let fragment = self.did.trim_start_matches("did:key:");
        format!("{}#{}", self.did, fragment)
    }

    /// Builds and signs a presentation of `issued`, disclosing the claims named in `reveal`.
    pub fn present(&self, issued: &IssuedCredential, reveal: &[&str], nonce: &str, domain: &str) -> Value {
        let disclosures: Vec<&Disclosure> =
            issued.disclosures.iter().filter(|d| reveal.contains(&d.name.as_str())).collect();
        let mut vp = json!({
            "@context": ["https://www.w3.org/2018/credentials/v1"],
            "type": ["VerifiablePresentation"],
            "holder": self.did,
            "verifiableCredential": issued.credential,
            "disclosures": disclosures,
            "nonce": nonce,
            "domain": domain,
        });
        credential::sign(&mut vp, &self.key, &self.key_id(), "authentication", NOW);
        vp
    }
}

pub fn membership_request(holder: &Holder) -> CredentialRequest {
    CredentialRequest {
        holder: holder.did.clone(),
        credential_type: "MembershipCredential".into(),
        claims: vec![
            ("member".into(), json!(true)),
            ("tier".into(), json!("gold")),
            ("birthdate".into(), json!("1990-04-12")),
        ],
        issued_at: NOW - 30 * DAY,
        not_before: None,
        expires_at: NOW + 180 * DAY,
    }
}

pub fn store() -> Arc<Store> {
    Arc::new(Store::from_onboarding_data().expect("onboarding data parses"))
}

pub fn harbour_document() -> Value {
    json!({
        "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
        "id": HARBOUR_DID,
        "verificationMethod": [{
            "id": HARBOUR_KEY_ID,
            "type": "Multikey",
            "controller": HARBOUR_DID,
            "publicKeyMultibase": HARBOUR_PUBLIC
        }],
        "authentication": [HARBOUR_KEY_ID],
        "assertionMethod": [HARBOUR_KEY_ID],
        "service": [{
            "id": format!("{HARBOUR_DID}#site"),
            "type": "LinkedDomains",
            "serviceEndpoint": "https://harbourclub.example/"
        }]
    })
}

pub const HARBOUR_URL: &str = "https://members.harbourclub.example/.well-known/did.json";

pub fn transport() -> StaticTransport {
    StaticTransport::default().with(HARBOUR_URL, harbour_document().to_string())
}

pub fn verifier(store: Arc<Store>) -> Verifier {
    let resolver = Resolver::new(Arc::new(transport()));
    Verifier::new(resolver, store).with_clock(|| NOW)
}

pub fn submission(request_id: &str, presentation: Value) -> Submission {
    Submission { request_id: request_id.into(), presentation }
}
