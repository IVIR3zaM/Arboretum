mod common;

use credentials_backend::store::{CredentialRecord, Store};

use common::*;

#[test]
fn onboarding_data_loads_every_approved_issuer() {
    let store = Store::from_onboarding_data().unwrap();
    let issuers = store.onboarded_issuers();
    assert!(issuers.len() >= 4, "{} issuers", issuers.len());
    for issuer in &issuers {
        assert_eq!(issuer.document.id.as_str(), issuer.did, "document id matches the DID");
        assert!(!issuer.document.assertion_method.is_empty(), "{} can sign", issuer.did);
        assert!(!issuer.name.is_empty());
    }
}

#[test]
fn onboarded_issuers_are_looked_up_by_did() {
    let store = Store::from_onboarding_data().unwrap();
    let harbour = store.onboarded_issuer(HARBOUR_DID).expect("harbour is onboarded");
    assert_eq!(harbour.name, "Harbour Club");
    let key = harbour.document.verification_method.iter().find(|vm| vm.id.as_str() == HARBOUR_KEY_ID).unwrap();
    assert_eq!(key.property_set["publicKeyMultibase"], HARBOUR_PUBLIC);
    assert!(store.onboarded_issuer("did:web:unknown.example").is_none());
}

#[test]
fn a_new_store_is_empty() {
    let store = Store::new();
    assert!(store.onboarded_issuers().is_empty());
    assert!(store.credential("urn:uuid:nothing").is_none());
}

#[test]
fn credential_records_round_trip() {
    let store = Store::new();
    let record = CredentialRecord {
        id: "urn:uuid:1".into(),
        issuer: HARBOUR_DID.into(),
        subject: "did:key:z6Mkexample".into(),
        status_list: "list-a".into(),
        status_index: 4,
        expires_at: NOW,
    };
    store.record_credential(record.clone());
    assert_eq!(store.credential("urn:uuid:1"), Some(record));
}

#[test]
fn status_indexes_are_unique_per_list() {
    let store = Store::new();
    let a = store.allocate_status_index("list-a").unwrap();
    let b = store.allocate_status_index("list-a").unwrap();
    let c = store.allocate_status_index("list-b").unwrap();
    assert_ne!(a, b);
    assert!(store.is_revoked("list-b", c) == Some(false));
    assert_eq!(store.is_revoked("list-missing", 0), None);
}
