mod common;

use credentials_backend::credential::{self, canonicalize, Disclosure};
use ed25519_dalek::SigningKey;
use serde_json::json;

#[test]
fn canonical_form_sorts_keys_and_drops_whitespace() {
    let value = json!({ "b": 2, "a": [1, "x", true, null, { "d": {}, "c": [] }] });
    assert_eq!(canonicalize(&value), r#"{"a":[1,"x",true,null,{"c":[],"d":{}}],"b":2}"#);
}

#[test]
fn canonical_form_orders_keys_by_utf16_code_units() {
    // U+1F600 is a surrogate pair (0xD83D..) and sorts before U+FB01 in UTF-16,
    // although its UTF-8 encoding sorts after.
    let value = json!({ "\u{FB01}": 1, "\u{1F600}": 2, "a": 3 });
    assert_eq!(canonicalize(&value), "{\"a\":3,\"\u{1F600}\":2,\"\u{FB01}\":1}");
}

#[test]
fn canonical_form_escapes_only_what_json_requires() {
    let value = json!({ "s": "quote\" slash\\ tab\t nl\n ctl\u{1} é /" });
    assert_eq!(canonicalize(&value), "{\"s\":\"quote\\\" slash\\\\ tab\\t nl\\n ctl\\u0001 é /\"}");
}

#[test]
fn canonical_form_writes_integral_numbers_without_a_fraction() {
    assert_eq!(canonicalize(&json!([1.0, -0.0, 2.5, 1_780_272_000i64])), "[1,0,2.5,1780272000]");
}

#[test]
fn disclosure_digest_is_sha256_of_the_canonical_triple() {
    let d = Disclosure { salt: "c2FsdA".into(), name: "member".into(), value: json!(true) };
    // sha256(`["c2FsdA","member",true]`), base64url without padding
    assert_eq!(d.digest(), "c-ZiuLoNN9HMsfOE2LQWHZNCZJLLnzaxRm_5gNAPlR8");
}

#[test]
fn signed_documents_verify_and_tampering_is_detected() {
    let key = SigningKey::from_bytes(&[3; 32]);
    let mut doc = json!({ "hello": "world", "n": 1 });
    credential::sign(&mut doc, &key, "did:example:1#k", "assertionMethod", 1_700_000_000);

    let proof = &doc["proof"];
    assert_eq!(proof["type"], credential::ED25519_SIGNATURE_2020);
    assert_eq!(proof["verificationMethod"], "did:example:1#k");
    assert_eq!(proof["proofPurpose"], "assertionMethod");
    assert!(proof["proofValue"].as_str().unwrap().starts_with('z'));

    assert!(credential::verify_signature(&doc, &key.verifying_key()).is_ok());
    doc["n"] = json!(2);
    assert!(credential::verify_signature(&doc, &key.verifying_key()).is_err());
}

#[test]
fn signing_input_excludes_the_proof() {
    let key = SigningKey::from_bytes(&[4; 32]);
    let mut doc = json!({ "a": 1 });
    let before = credential::signing_input(&doc);
    credential::sign(&mut doc, &key, "did:example:1#k", "assertionMethod", 0);
    assert_eq!(credential::signing_input(&doc), before);
    assert_eq!(before, br#"{"a":1}"#.to_vec());
}
