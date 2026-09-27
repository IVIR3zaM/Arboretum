//! DID resolution: from a DID to its DID document.
//!
//! The methods the service has used, oldest first:
//!
//! - `did:key` — the identifier is one multibase-encoded Ed25519 key.
//! - `did:peer:0` — the same, under the peer method.
//! - `did:peer:2` — several keys, each tagged with its purpose, plus service
//!   endpoints, all encoded in the identifier.
//! - `did:web` — the document is published at an HTTPS URL derived from the
//!   identifier and fetched through a [`DocumentTransport`].

use std::sync::Arc;

use affinidi_did_common::Document;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use ed25519_dalek::VerifyingKey;
use serde_json::{json, Map, Value};
use thiserror::Error;

use crate::transport::{DocumentTransport, TransportError};

#[derive(Debug, Error)]
pub enum ResolveError {
    #[error("invalid DID {0}")]
    InvalidDid(String),
    #[error("unsupported DID method {0}")]
    UnsupportedMethod(String),
    #[error(transparent)]
    Transport(#[from] TransportError),
    #[error("document for {did} is not a valid DID document: {reason}")]
    InvalidDocument { did: String, reason: String },
    #[error("document fetched for {did} is for {found}")]
    DocumentMismatch { did: String, found: String },
}

#[derive(Clone)]
pub struct Resolver {
    transport: Arc<dyn DocumentTransport>,
}

impl Resolver {
    pub fn new(transport: Arc<dyn DocumentTransport>) -> Self {
        Resolver { transport }
    }

    pub fn resolve(&self, did: &str) -> Result<Document, ResolveError> {
        let method = did
            .strip_prefix("did:")
            .and_then(|rest| rest.split_once(':'))
            .map(|(method, _)| method)
            .ok_or_else(|| ResolveError::InvalidDid(did.to_string()))?;
        match method {
            "key" => resolve_key(did),
            "peer" => resolve_peer(did),
            "web" => self.resolve_web(did),
            other => Err(ResolveError::UnsupportedMethod(other.to_string())),
        }
    }

    fn resolve_web(&self, did: &str) -> Result<Document, ResolveError> {
        let url = did_web_url(did)?;
        let body = self.transport.get(&url)?;
        let document: Document = serde_json::from_slice(&body)
            .map_err(|e| ResolveError::InvalidDocument { did: did.to_string(), reason: e.to_string() })?;
        if document.id.as_str() != did {
            return Err(ResolveError::DocumentMismatch { did: did.to_string(), found: document.id.to_string() });
        }
        Ok(document)
    }
}

/// The `did:key` identifier for an Ed25519 public key.
pub fn did_key_for(key: &VerifyingKey) -> String {
    format!("did:key:{}", affinidi_encoding::encode_multikey(affinidi_encoding::ED25519_PUB, key.as_bytes()))
}

/// The HTTPS URL a `did:web` document is published at: `did.json` under the
/// host's `/.well-known/` directory, with any further segments of the
/// identifier as subdirectories. A port is written percent-encoded in the host
/// segment (`example.com%3A8443`).
pub fn did_web_url(did: &str) -> Result<String, ResolveError> {
    let invalid = || ResolveError::InvalidDid(did.to_string());
    let id = did.strip_prefix("did:web:").ok_or_else(invalid)?;
    let mut segments = id.split(':');
    let host = percent_decode(segments.next().unwrap_or_default()).ok_or_else(invalid)?;
    if host.is_empty() || host.contains('/') {
        return Err(invalid());
    }
    let path: Vec<String> = segments.map(percent_decode).collect::<Option<_>>().ok_or_else(invalid)?;
    if path.iter().any(|s| s.is_empty() || s.contains('/')) {
        return Err(invalid());
    }
    let mut url = format!("https://{host}/.well-known");
    for segment in &path {
        url.push('/');
        url.push_str(segment);
    }
    url.push_str("/did.json");
    Ok(url)
}

fn percent_decode(segment: &str) -> Option<String> {
    let bytes = segment.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' {
            let hex = std::str::from_utf8(bytes.get(i + 1..i + 3)?).ok()?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

fn resolve_key(did: &str) -> Result<Document, ResolveError> {
    let multibase = did.strip_prefix("did:key:").unwrap_or_default();
    single_key_document(did, multibase)
}

fn resolve_peer(did: &str) -> Result<Document, ResolveError> {
    let id = did.strip_prefix("did:peer:").unwrap_or_default();
    if let Some(multibase) = id.strip_prefix('0') {
        single_key_document(did, multibase)
    } else if let Some(elements) = id.strip_prefix("2.") {
        peer_2_document(did, elements)
    } else {
        Err(ResolveError::InvalidDid(did.to_string()))
    }
}

/// Checks that `multibase` is an Ed25519 multikey.
fn ed25519_multikey(did: &str, multibase: &str) -> Result<(), ResolveError> {
    match affinidi_encoding::decode_multikey_with_codec(multibase) {
        Ok((affinidi_encoding::ED25519_PUB, bytes)) if bytes.len() == 32 => Ok(()),
        _ => Err(ResolveError::InvalidDid(did.to_string())),
    }
}

fn multikey(id: &str, controller: &str, multibase: &str) -> Value {
    json!({ "id": id, "type": "Multikey", "controller": controller, "publicKeyMultibase": multibase })
}

fn single_key_document(did: &str, multibase: &str) -> Result<Document, ResolveError> {
    ed25519_multikey(did, multibase)?;
    let vm_id = format!("{did}#{multibase}");
    to_document(did, json!({
        "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
        "id": did,
        "verificationMethod": [multikey(&vm_id, did, multibase)],
        "authentication": [vm_id],
        "assertionMethod": [vm_id],
        "capabilityInvocation": [vm_id],
        "capabilityDelegation": [vm_id],
    }))
}

fn peer_2_document(did: &str, elements: &str) -> Result<Document, ResolveError> {
    let invalid = || ResolveError::InvalidDid(did.to_string());
    let mut methods = Vec::new();
    let mut relationships: Map<String, Value> = Map::new();
    let mut services = Vec::new();

    for element in elements.split('.') {
        let mut chars = element.chars();
        let purpose = chars.next().ok_or_else(invalid)?;
        let body = chars.as_str();
        let relationship = match purpose {
            'A' => "assertionMethod",
            'V' => "authentication",
            'E' => "keyAgreement",
            'I' => "capabilityInvocation",
            'D' => "capabilityDelegation",
            'S' => {
                let raw = URL_SAFE_NO_PAD.decode(body.trim_end_matches('=')).map_err(|_| invalid())?;
                let abbreviated: Value = serde_json::from_slice(&raw).map_err(|_| invalid())?;
                let id = match services.len() {
                    0 => format!("{did}#service"),
                    n => format!("{did}#service-{n}"),
                };
                let mut service = expand_service(&abbreviated);
                service["id"] = json!(id);
                services.push(service);
                continue;
            }
            _ => return Err(invalid()),
        };
        if purpose != 'E' {
            ed25519_multikey(did, body)?;
        }
        let vm_id = format!("{did}#key-{}", methods.len() + 1);
        methods.push(multikey(&vm_id, did, body));
        relationships.entry(relationship).or_insert_with(|| json!([])).as_array_mut().unwrap().push(json!(vm_id));
    }

    let mut document = json!({
        "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
        "id": did,
        "verificationMethod": methods,
        "service": services,
    });
    for (relationship, ids) in relationships {
        document[relationship] = ids;
    }
    to_document(did, document)
}

/// Expands the abbreviated keys peer:2 uses for services (`t`, `s`, `r`, `a`, `dm`).
fn expand_service(value: &Value) -> Value {
    match value {
        Value::Object(map) => Value::Object(
            map.iter()
                .map(|(k, v)| {
                    let key = match k.as_str() {
                        "t" => "type",
                        "s" => "serviceEndpoint",
                        "r" => "routingKeys",
                        "a" => "accept",
                        other => other,
                    };
                    (key.to_string(), expand_service(v))
                })
                .collect(),
        ),
        Value::String(s) if s == "dm" => json!("DIDCommMessaging"),
        Value::Array(items) => Value::Array(items.iter().map(expand_service).collect()),
        other => other.clone(),
    }
}

fn to_document(did: &str, value: Value) -> Result<Document, ResolveError> {
    serde_json::from_value(value)
        .map_err(|e| ResolveError::InvalidDocument { did: did.to_string(), reason: e.to_string() })
}
