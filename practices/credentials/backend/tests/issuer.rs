mod common;

use std::sync::Arc;

use credentials_backend::credential;
use credentials_backend::issuer::{onboard, IssueError};
use credentials_backend::resolver::Resolver;
use credentials_backend::store::Store;
use credentials_backend::transport::StaticTransport;
use serde_json::json;

use common::*;

#[test]
fn issued_credentials_carry_the_wire_fields() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vc = &issued.credential;

    assert_eq!(vc["issuer"], HARBOUR_DID);
    assert_eq!(vc["type"], json!(["VerifiableCredential", "MembershipCredential"]));
    assert!(vc["id"].as_str().unwrap().starts_with("urn:uuid:"));
    assert_eq!(vc["credentialSubject"]["id"], holder.did.as_str());
    assert_eq!(vc["issued_at"], NOW - 30 * DAY);
    assert_eq!(vc["not_before"], NOW - 30 * DAY);
    assert_eq!(vc["expires_at"], NOW + 180 * DAY);
    assert_eq!(vc["credentialStatus"]["type"], "StatusListEntry");
    assert!(vc["credentialStatus"]["statusListIndex"].is_u64());
    assert_eq!(vc["proof"]["verificationMethod"], HARBOUR_KEY_ID);
    assert_eq!(vc["proof"]["proofPurpose"], "assertionMethod");
}

#[test]
fn claims_are_carried_only_as_salted_digests() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let digests: Vec<&str> = issued.credential["credentialSubject"]["_sd"]
        .as_array()
        .unwrap()
        .iter()
        .map(|d| d.as_str().unwrap())
        .collect();

    assert_eq!(issued.disclosures.len(), 3);
    for disclosure in &issued.disclosures {
        assert!(digests.contains(&disclosure.digest().as_str()), "{} is committed", disclosure.name);
        assert!(disclosure.salt.len() >= 16);
    }
    let text = issued.credential.to_string();
    assert!(!text.contains("gold") && !text.contains("1990-04-12"), "claim values stay out of the VC");
}

#[test]
fn every_issue_uses_fresh_salts() {
    let store = store();
    let holder = Holder::new(1);
    let a = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let b = harbour().issue(&store, &membership_request(&holder)).unwrap();
    assert_ne!(a.disclosures[0].salt, b.disclosures[0].salt);
    assert_ne!(a.credential["id"], b.credential["id"]);
}

#[test]
fn the_issuer_proof_verifies_with_the_issuer_key() {
    let store = store();
    let holder = Holder::new(1);
    let issuer = harbour();
    let issued = issuer.issue(&store, &membership_request(&holder)).unwrap();
    assert!(credential::verify_signature(&issued.credential, &issuer.verifying_key()).is_ok());
}

#[test]
fn issuance_is_recorded_in_the_store() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let record = store.credential(issued.credential["id"].as_str().unwrap()).unwrap();
    assert_eq!(record.issuer, HARBOUR_DID);
    assert_eq!(record.subject, holder.did);
    assert_eq!(record.status_index as u64, issued.credential["credentialStatus"]["statusListIndex"].as_u64().unwrap());
}

#[test]
fn holders_must_be_did_key() {
    let store = store();
    let mut request = membership_request(&Holder::new(1));
    request.holder = "did:web:someone.example".into();
    assert!(matches!(harbour().issue(&store, &request), Err(IssueError::InvalidHolder(_))));
}

#[test]
fn an_expiry_before_issuance_is_refused() {
    let store = store();
    let mut request = membership_request(&Holder::new(1));
    request.expires_at = request.issued_at - 1;
    assert!(matches!(harbour().issue(&store, &request), Err(IssueError::InvalidValidity)));
}

#[test]
fn onboarding_records_the_published_document() {
    let resolver = Resolver::new(Arc::new(transport()));
    let store = Store::new();

    let record = onboard(&resolver, &store, HARBOUR_DID, "Harbour Club", "2026-06-01").unwrap();
    assert_eq!(record.document.id.as_str(), HARBOUR_DID);
    assert_eq!(store.onboarded_issuer(HARBOUR_DID), Some(record));
}

#[test]
fn onboarding_fails_when_the_document_is_unavailable() {
    let resolver = Resolver::new(Arc::new(StaticTransport::default()));
    let store = Store::new();
    assert!(onboard(&resolver, &store, HARBOUR_DID, "Harbour Club", "2026-06-01").is_err());
    assert!(store.onboarded_issuer(HARBOUR_DID).is_none());
}
