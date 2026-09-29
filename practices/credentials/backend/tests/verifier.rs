mod common;

use credentials_backend::credential;
use credentials_backend::status::revoke_credential;
use credentials_backend::verifier::VerifyError;
use serde_json::json;

use common::*;

#[test]
fn a_presentation_discloses_only_the_requested_claims() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = holder.present(&issued, &["member"], NONCE, DOMAIN);

    let verified = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap();
    assert_eq!(verified.holder, holder.did);
    assert_eq!(verified.credential.issuer, HARBOUR_DID);
    assert_eq!(verified.claims.len(), 1);
    assert_eq!(verified.claims["member"], json!(true));
}

#[test]
fn every_claim_can_be_disclosed() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = holder.present(&issued, &["member", "tier", "birthdate"], NONCE, DOMAIN);

    let verified = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap();
    assert_eq!(verified.claims["tier"], json!("gold"));
    assert_eq!(verified.claims["birthdate"], json!("1990-04-12"));
}

#[test]
fn a_credential_verifies_on_its_own() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();

    let verified = verifier(store).verify_credential(&issued.credential).unwrap();
    assert_eq!(verified.issuer, HARBOUR_DID);
    assert_eq!(verified.subject, holder.did);
    assert_eq!(verified.expires_at, NOW + 180 * DAY);
    assert_eq!(verified.issuer_site.as_deref(), Some("https://harbourclub.example/"));
}

#[test]
fn the_issuer_document_is_the_one_harbour_publishes() {
    let doc = verifier(store()).resolve_issuer(HARBOUR_DID).unwrap();
    let key = doc.verification_method.iter().find(|vm| vm.id.as_str() == HARBOUR_KEY_ID).unwrap();
    assert_eq!(key.property_set["publicKeyMultibase"], HARBOUR_PUBLIC);
}

#[test]
fn a_presentation_for_another_nonce_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = holder.present(&issued, &["member"], "an-older-nonce", DOMAIN);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::NonceMismatch), "{err:?}");
}

#[test]
fn a_presentation_for_another_domain_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = holder.present(&issued, &["member"], NONCE, "door.elsewhere.example");
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::DomainMismatch), "{err:?}");
}

#[test]
fn the_same_submission_is_accepted_once() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = holder.present(&issued, &["member"], NONCE, DOMAIN);
    let verifier = verifier(store);
    verifier.verify_presentation(&submission("req-1", vp.clone()), NONCE, DOMAIN).unwrap();
    let err = verifier.verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::Replay), "{err:?}");
}

#[test]
fn a_tampered_disclosure_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let mut issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let tier = issued.disclosures.iter_mut().find(|d| d.name == "tier").unwrap();
    tier.value = json!("platinum");
    let vp = holder.present(&issued, &["tier"], NONCE, DOMAIN);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::UndisclosedClaim(ref name) if name == "tier"), "{err:?}");
}

#[test]
fn a_tampered_credential_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let mut issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    issued.credential["expires_at"] = json!(NOW + 3650 * DAY);
    let vp = holder.present(&issued, &["member"], NONCE, DOMAIN);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::BadSignature(_)), "{err:?}");
}

#[test]
fn a_presentation_signed_by_someone_else_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let thief = Holder::new(9);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let mut vp = holder.present(&issued, &["member"], NONCE, DOMAIN);
    credential::sign(&mut vp, &thief.key, &holder.key_id(), "authentication", NOW);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::BadSignature(_)), "{err:?}");
}

#[test]
fn a_credential_presented_by_another_holder_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let thief = Holder::new(9);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let vp = thief.present(&issued, &["member"], NONCE, DOMAIN);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::HolderMismatch), "{err:?}");
}

#[test]
fn an_expired_credential_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let mut request = membership_request(&holder);
    request.expires_at = NOW - DAY;
    let issued = harbour().issue(&store, &request).unwrap();
    let err = verifier(store).verify_credential(&issued.credential).unwrap_err();
    assert!(matches!(err, VerifyError::Expired), "{err:?}");
}

#[test]
fn a_credential_that_is_not_yet_valid_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let mut request = membership_request(&holder);
    request.not_before = Some(NOW + DAY);
    let issued = harbour().issue(&store, &request).unwrap();
    let err = verifier(store).verify_credential(&issued.credential).unwrap_err();
    assert!(matches!(err, VerifyError::NotYetValid), "{err:?}");
}

#[test]
fn a_revoked_credential_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    revoke_credential(&store, issued.credential["id"].as_str().unwrap()).unwrap();
    let vp = holder.present(&issued, &["member"], NONCE, DOMAIN);
    let err = verifier(store).verify_presentation(&submission("req-1", vp), NONCE, DOMAIN).unwrap_err();
    assert!(matches!(err, VerifyError::Revoked), "{err:?}");
}

#[test]
fn a_proof_by_a_key_the_issuer_does_not_list_is_rejected() {
    let store = store();
    let holder = Holder::new(1);
    let mut issued = harbour().issue(&store, &membership_request(&holder)).unwrap();
    let key = ed25519_dalek::SigningKey::from_bytes(&seed(HARBOUR_SEED));
    let unlisted = format!("{HARBOUR_DID}#key-9");
    credential::sign(&mut issued.credential, &key, &unlisted, "assertionMethod", NOW);
    let err = verifier(store).verify_credential(&issued.credential).unwrap_err();
    assert!(matches!(err, VerifyError::UnknownKey(ref id) if *id == unlisted), "{err:?}");
}

#[test]
fn a_credential_without_an_issuer_is_malformed() {
    let err = verifier(store()).verify_credential(&json!({ "credentialSubject": {} })).unwrap_err();
    assert!(matches!(err, VerifyError::Malformed(_)), "{err:?}");
}
