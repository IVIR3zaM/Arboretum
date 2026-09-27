//! Onboarding issuers and issuing credentials on their behalf.

use ed25519_dalek::{SigningKey, VerifyingKey};
use serde_json::{json, Value};
use thiserror::Error;

use crate::credential::{self, Disclosure, CREDENTIALS_CONTEXT};
use crate::resolver::{ResolveError, Resolver};
use crate::store::{CredentialRecord, OnboardedIssuer, Store};

#[derive(Debug, Error)]
pub enum OnboardError {
    #[error(transparent)]
    Resolve(#[from] ResolveError),
    #[error("{0} publishes no assertion key")]
    NoAssertionKey(String),
}

/// Approves an issuer: resolves its DID and records it with its document.
pub fn onboard(
    resolver: &Resolver,
    store: &Store,
    did: &str,
    name: &str,
    onboarded_at: &str,
) -> Result<OnboardedIssuer, OnboardError> {
    let document = resolver.resolve(did)?;
    if document.assertion_method.is_empty() {
        return Err(OnboardError::NoAssertionKey(did.to_string()));
    }
    let record = OnboardedIssuer {
        did: did.to_string(),
        name: name.to_string(),
        onboarded_at: onboarded_at.to_string(),
        document,
    };
    store.record_onboarded_issuer(record.clone());
    Ok(record)
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum IssueError {
    #[error("holder {0} is not a did:key")]
    InvalidHolder(String),
    #[error("credential would expire before it becomes valid")]
    InvalidValidity,
    #[error("status list {0} is full")]
    StatusListFull(String),
}

/// What a member asked for.
#[derive(Debug, Clone)]
pub struct CredentialRequest {
    /// The holder's `did:key`.
    pub holder: String,
    /// Added to `type` after `VerifiableCredential`.
    pub credential_type: String,
    pub claims: Vec<(String, Value)>,
    /// Unix seconds.
    pub issued_at: i64,
    /// Unix seconds; defaults to `issued_at`.
    pub not_before: Option<i64>,
    /// Unix seconds.
    pub expires_at: i64,
}

/// A signed credential plus the disclosures only its holder receives.
#[derive(Debug, Clone)]
pub struct IssuedCredential {
    pub credential: Value,
    pub disclosures: Vec<Disclosure>,
}

/// An onboarded issuer's signing identity.
pub struct Issuer {
    did: String,
    verification_method: String,
    key: SigningKey,
}

impl Issuer {
    /// `verification_method` is the DID URL of the key in the issuer's document.
    pub fn new(did: &str, verification_method: &str, seed: &[u8; 32]) -> Self {
        Issuer {
            did: did.to_string(),
            verification_method: verification_method.to_string(),
            key: SigningKey::from_bytes(seed),
        }
    }

    pub fn did(&self) -> &str {
        &self.did
    }

    pub fn verifying_key(&self) -> VerifyingKey {
        self.key.verifying_key()
    }

    /// The status list this issuer's credentials are indexed into.
    pub fn status_list(&self) -> String {
        format!("{}#revocation", self.did)
    }

    pub fn issue(&self, store: &Store, request: &CredentialRequest) -> Result<IssuedCredential, IssueError> {
        let holder_key = request.holder.strip_prefix("did:key:").unwrap_or_default();
        match affinidi_encoding::decode_multikey_with_codec(holder_key) {
            Ok((affinidi_encoding::ED25519_PUB, _)) => {}
            _ => return Err(IssueError::InvalidHolder(request.holder.clone())),
        }
        let not_before = request.not_before.unwrap_or(request.issued_at);
        if request.expires_at < not_before {
            return Err(IssueError::InvalidValidity);
        }

        let disclosures: Vec<Disclosure> =
            request.claims.iter().map(|(name, value)| Disclosure::new(name, value.clone())).collect();
        let mut digests: Vec<String> = disclosures.iter().map(Disclosure::digest).collect();
        digests.sort();

        let status_list = self.status_list();
        let status_index =
            store.allocate_status_index(&status_list).ok_or_else(|| IssueError::StatusListFull(status_list.clone()))?;

        let id = credential::random_urn();
        let mut vc = json!({
            "@context": [CREDENTIALS_CONTEXT],
            "id": id,
            "type": ["VerifiableCredential", request.credential_type],
            "issuer": self.did,
            "issued_at": request.issued_at,
            "not_before": not_before,
            "expires_at": request.expires_at,
            "credentialSubject": { "id": request.holder, "_sd": digests },
            "credentialStatus": {
                "type": "StatusListEntry",
                "statusListId": status_list,
                "statusListIndex": status_index,
            },
        });
        credential::sign(&mut vc, &self.key, &self.verification_method, "assertionMethod", request.issued_at);

        store.record_credential(CredentialRecord {
            id,
            issuer: self.did.clone(),
            subject: request.holder.clone(),
            status_list,
            status_index,
            expires_at: request.expires_at,
        });
        Ok(IssuedCredential { credential: vc, disclosures })
    }
}
