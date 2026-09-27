mod common;

use credentials_backend::issuer::CredentialRequest;
use credentials_backend::status::{revoke_credential, StatusError, StatusList};
use credentials_backend::store::Store;

use common::*;

#[test]
fn a_new_list_has_nothing_revoked() {
    let list = StatusList::new(64);
    assert_eq!(list.capacity(), 64);
    assert!((0..64).all(|i| !list.is_set(i)));
}

#[test]
fn setting_a_bit_only_touches_that_index() {
    let mut list = StatusList::new(64);
    list.set(5, true);
    assert!(list.is_set(5));
    assert!(!list.is_set(4));
    assert!(!list.is_set(6));
    list.set(5, false);
    assert!(!list.is_set(5));
}

#[test]
fn the_encoded_list_round_trips() {
    let mut list = StatusList::new(64);
    list.set(3, true);
    list.set(40, true);
    let decoded = StatusList::decode(&list.encode(), 64).unwrap();
    assert!(decoded.is_set(3) && decoded.is_set(40));
    assert!(!decoded.is_set(2));
}

#[test]
fn allocation_hands_out_distinct_indexes() {
    let mut list = StatusList::new(64);
    let first = list.allocate().unwrap();
    let second = list.allocate().unwrap();
    assert_ne!(first, second);
}

#[test]
fn revoking_a_credential_flips_its_status() {
    let store = Store::from_onboarding_data().unwrap();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let id = issued.credential["id"].as_str().unwrap();
    let record = store.credential(id).unwrap();
    assert_eq!(store.is_revoked(&record.status_list, record.status_index), Some(false));

    let change = revoke_credential(&store, id).unwrap();
    assert_eq!(change.credential_id, id);
    assert_eq!(change.issuer, HARBOUR_DID);
    assert_eq!(store.is_revoked(&record.status_list, record.status_index), Some(true));
}

#[test]
fn revoking_an_unknown_credential_fails() {
    let store = Store::new();
    assert!(matches!(revoke_credential(&store, "urn:uuid:missing"), Err(StatusError::UnknownCredential(_))));
}

#[test]
fn revoking_one_credential_leaves_the_others_valid() {
    let store = Store::from_onboarding_data().unwrap();
    let holder = Holder::new(2);
    let request: CredentialRequest = membership_request(&holder);
    let first = harbour().issue(&store, &request).unwrap();
    let second = harbour().issue(&store, &request).unwrap();
    revoke_credential(&store, first.credential["id"].as_str().unwrap()).unwrap();
    let other = store.credential(second.credential["id"].as_str().unwrap()).unwrap();
    assert_eq!(store.is_revoked(&other.status_list, other.status_index), Some(false));
}
