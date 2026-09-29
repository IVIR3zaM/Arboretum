//! Checking the presentations members show at the door.

use std::collections::{BTreeMap, HashSet};
use std::sync::{Arc, Mutex};

use affinidi_did_common::verification_method::VerificationRelationship;
use affinidi_did_common::Document;
use ed25519_dalek::VerifyingKey;
use serde_json::Value;
use thiserror::Error;

use crate::credential::{self, Disclosure, ED25519_SIGNATURE_2020};
use crate::resolver::{ResolveError, Resolver};
use crate::store::Store;

#[derive(Debug, Error)]
pub enum VerifyError {
    #[error("malformed: {0}")]
    Malformed(String),
    #[error("presentation already submitted")]
    Replay,
    #[error("presentation is bound to another nonce")]
    NonceMismatch,
    #[error("presentation is bound to another domain")]
    DomainMismatch,
    #[error("credential subject is not the presenting holder")]
    HolderMismatch,
    #[error(transparent)]
    Resolve(#[from] ResolveError),
    #[error("{0} is not a key its controller signs with")]
    UnknownKey(String),
    #[error("bad signature: {0}")]
    BadSignature(String),
    #[error("credential has expired")]
    Expired,
    #[error("credential is not valid yet")]
    NotYetValid,
    #[error("credential has been revoked")]
    Revoked,
    #[error("no status list {0}")]
    UnknownStatus(String),
    #[error("claim {0} was not issued in this credential")]
    UndisclosedClaim(String),
}

/// A presentation as it arrives from the door scanner.
#[derive(Debug, Clone)]
pub struct Submission {
    /// Set by the scanner's transport for each upload.
    pub request_id: String,
    pub presentation: Value,
}

#[derive(Debug, Clone, PartialEq)]
pub struct VerifiedCredential {
    pub id: String,
    pub issuer: String,
    pub subject: String,
    pub expires_at: i64,
    /// The issuer's `LinkedDomains` endpoint, shown to door staff.
    pub issuer_site: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct VerifiedPresentation {
    pub holder: String,
    pub credential: VerifiedCredential,
    /// The claims the holder chose to disclose.
    pub claims: BTreeMap<String, Value>,
}

#[derive(Default)]
struct ReplayGuard {
    seen_nonces: HashSet<String>,
}

impl ReplayGuard {
    fn first_use(&mut self, key: &str) -> bool {
        self.seen_nonces.insert(key.to_string())
    }
}

type Clock = Box<dyn Fn() -> i64 + Send + Sync>;

pub struct Verifier {
    resolver: Resolver,
    store: Arc<Store>,
    clock: Clock,
    replay: Mutex<ReplayGuard>,
}

impl Verifier {
    pub fn new(resolver: Resolver, store: Arc<Store>) -> Self {
        Verifier { resolver, store, clock: Box::new(unix_now), replay: Mutex::default() }
    }

    /// Replaces the wall clock (unix seconds).
    pub fn with_clock(mut self, clock: impl Fn() -> i64 + Send + Sync + 'static) -> Self {
        self.clock = Box::new(clock);
        self
    }

    /// Verifies a presentation against the nonce and domain the scanner issued.
    pub fn verify_presentation(
        &self,
        submission: &Submission,
        expected_nonce: &str,
        expected_domain: &str,
    ) -> Result<VerifiedPresentation, VerifyError> {
        let vp = &submission.presentation;
        if !self.replay.lock().unwrap_or_else(|p| p.into_inner()).first_use(&submission.request_id) {
            return Err(VerifyError::Replay);
        }
        if str_field(vp, "nonce")? != expected_nonce {
            return Err(VerifyError::NonceMismatch);
        }
        if str_field(vp, "domain")? != expected_domain {
            return Err(VerifyError::DomainMismatch);
        }

        let holder = str_field(vp, "holder")?;
        match self.resolver.resolve(holder) {
            Ok(document) => check_proof(vp, &document, &document.authentication)?,
            Err(ResolveError::UnsupportedMethod(_)) => {}
            Err(e) => return Err(e.into()),
        }

        let vc = vp.get("verifiableCredential").ok_or_else(|| malformed("verifiableCredential"))?;
        let credential = self.verify_credential(vc)?;
        if credential.subject != holder {
            return Err(VerifyError::HolderMismatch);
        }

        let committed: HashSet<&str> = vc
            .pointer("/credentialSubject/_sd")
            .and_then(Value::as_array)
            .map(|digests| digests.iter().filter_map(Value::as_str).collect())
            .unwrap_or_default();
        let disclosures: Vec<Disclosure> = match vp.get("disclosures") {
            Some(list) => serde_json::from_value(list.clone()).map_err(|_| malformed("disclosures"))?,
            None => Vec::new(),
        };
        let mut claims = BTreeMap::new();
        for disclosure in disclosures {
            if !committed.contains(disclosure.digest().as_str()) {
                return Err(VerifyError::UndisclosedClaim(disclosure.name));
            }
            claims.insert(disclosure.name, disclosure.value);
        }

        Ok(VerifiedPresentation { holder: holder.to_string(), credential, claims })
    }

    /// Verifies a credential: issuer proof, validity window and status.
    pub fn verify_credential(&self, vc: &Value) -> Result<VerifiedCredential, VerifyError> {
        let issuer = str_field(vc, "issuer")?;
        let subject = vc.pointer("/credentialSubject/id").and_then(Value::as_str).ok_or_else(|| malformed("credentialSubject.id"))?;
        let id = str_field(vc, "id")?;

        let document = self.resolve_issuer(issuer)?;
        check_proof(vc, &document, &document.assertion_method)?;

        let now = (self.clock)();
        let not_before = int_field(vc, "not_before")?;
        let expires_at = int_field(vc, "expires_at")?;
        if now < not_before {
            return Err(VerifyError::NotYetValid);
        }
        if now > expires_at {
            return Err(VerifyError::Expired);
        }

        let list = vc.pointer("/credentialStatus/statusListId").and_then(Value::as_str).ok_or_else(|| malformed("credentialStatus"))?;
        let index = vc.pointer("/credentialStatus/statusListIndex").and_then(Value::as_u64).ok_or_else(|| malformed("credentialStatus"))?;
        match self.store.is_revoked(list, index as usize) {
            Some(false) => {}
            Some(true) => return Err(VerifyError::Revoked),
            None => return Err(VerifyError::UnknownStatus(list.to_string())),
        }

        let issuer_site = document
            .service
            .iter()
            .find(|service| service.type_.iter().any(|t| t == "LinkedDomains"))
            .and_then(|service| service.service_endpoint.get_uri());

        Ok(VerifiedCredential {
            id: id.to_string(),
            issuer: issuer.to_string(),
            subject: subject.to_string(),
            expires_at,
            issuer_site,
        })
    }

    /// The DID document an issuer's credentials are checked against.
    pub fn resolve_issuer(&self, did: &str) -> Result<Document, VerifyError> {
        if let Some(issuer) = self.store.onboarded_issuer(did) {
            return Ok(issuer.document);
        }
        Ok(self.resolver.resolve(did)?)
    }
}

/// Checks `document`'s proof against a key `signer` lists under `relationship`.
fn check_proof(document: &Value, signer: &Document, relationship: &[VerificationRelationship]) -> Result<(), VerifyError> {
    let proof = document.get("proof").ok_or_else(|| malformed("proof"))?;
    if proof.get("type").and_then(Value::as_str) == Some(ED25519_SIGNATURE_2020) {
        let method = proof.get("verificationMethod").and_then(Value::as_str).ok_or_else(|| malformed("proof.verificationMethod"))?;
        let key = listed_key(signer, relationship, method)?;
        credential::verify_signature(document, &key).map_err(VerifyError::BadSignature)?;
    }
    Ok(())
}

fn listed_key(signer: &Document, relationship: &[VerificationRelationship], method: &str) -> Result<VerifyingKey, VerifyError> {
    let unknown = || VerifyError::UnknownKey(method.to_string());
    let absolute = |reference: &str| match reference.strip_prefix('#') {
        Some(fragment) => format!("{}#{fragment}", signer.id),
        None => reference.to_string(),
    };
    let listed = relationship.iter().find_map(|entry| match entry {
        VerificationRelationship::Reference(reference) if absolute(reference) == method => {
            signer.verification_method.iter().find(|vm| absolute(vm.id.as_str()) == method).cloned()
        }
        VerificationRelationship::VerificationMethod(vm) if absolute(vm.id.as_str()) == method => Some((**vm).clone()),
        _ => None,
    });
    let vm = listed.ok_or_else(unknown)?;
    match vm.decode_public_key() {
        Ok((affinidi_encoding::ED25519_PUB, bytes)) => {
            let bytes: [u8; 32] = bytes.try_into().map_err(|_| unknown())?;
            VerifyingKey::from_bytes(&bytes).map_err(|_| unknown())
        }
        _ => Err(unknown()),
    }
}

fn malformed(field: &str) -> VerifyError {
    VerifyError::Malformed(format!("missing or invalid {field}"))
}

fn str_field<'a>(value: &'a Value, field: &str) -> Result<&'a str, VerifyError> {
    value.get(field).and_then(Value::as_str).ok_or_else(|| malformed(field))
}

fn int_field(value: &Value, field: &str) -> Result<i64, VerifyError> {
    value.get(field).and_then(Value::as_i64).ok_or_else(|| malformed(field))
}

fn unix_now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or_default()
}
