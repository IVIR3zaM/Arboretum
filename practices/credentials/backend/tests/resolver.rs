mod common;

use std::sync::Arc;

use credentials_backend::resolver::{did_key_for, did_web_url, ResolveError, Resolver};
use credentials_backend::transport::{DocumentTransport, MirrorTransport, StaticTransport};
use ed25519_dalek::SigningKey;
use serde_json::json;

use common::*;

fn resolver_with(transport: StaticTransport) -> Resolver {
    Resolver::new(Arc::new(transport))
}

fn key_multibase(doc: &affinidi_did_common::Document, vm_id: &str) -> String {
    let vm = doc.verification_method.iter().find(|vm| vm.id.as_str() == vm_id).expect("vm present");
    vm.property_set["publicKeyMultibase"].as_str().unwrap().to_string()
}

// --- did:key -------------------------------------------------------------

#[test]
fn did_key_decodes_to_a_single_ed25519_key() {
    let key = SigningKey::from_bytes(&[7; 32]);
    let did = did_key_for(&key.verifying_key());
    assert!(did.starts_with("did:key:z6Mk"));

    let doc = resolver_with(StaticTransport::default()).resolve(&did).unwrap();
    let fragment = did.trim_start_matches("did:key:");
    let vm_id = format!("{did}#{fragment}");
    assert_eq!(doc.id.as_str(), did);
    assert_eq!(key_multibase(&doc, &vm_id), fragment);
    assert_eq!(doc.authentication.len(), 1);
    assert_eq!(doc.assertion_method.len(), 1);
    assert!(doc.service.is_empty());
}

#[test]
fn did_key_with_a_non_ed25519_codec_is_rejected() {
    // multicodec 0xec (X25519) is a key-agreement key, not a signing key.
    let x25519 = affinidi_encoding::encode_multikey(affinidi_encoding::X25519_PUB, &[9; 32]);
    let err = resolver_with(StaticTransport::default()).resolve(&format!("did:key:{x25519}")).unwrap_err();
    assert!(matches!(err, ResolveError::InvalidDid(_)), "{err:?}");
}

// --- did:peer ------------------------------------------------------------

#[test]
fn did_peer_0_decodes_its_inception_key() {
    let key = SigningKey::from_bytes(&[8; 32]);
    let multibase = did_key_for(&key.verifying_key()).trim_start_matches("did:key:").to_string();
    let did = format!("did:peer:0{multibase}");

    let doc = resolver_with(StaticTransport::default()).resolve(&did).unwrap();
    assert_eq!(doc.id.as_str(), did);
    assert_eq!(key_multibase(&doc, &format!("{did}#{multibase}")), multibase);
    assert!(doc.service.is_empty());
}

#[test]
fn did_peer_2_decodes_keys_by_purpose_and_its_service() {
    let assertion = did_key_for(&SigningKey::from_bytes(&[10; 32]).verifying_key());
    let auth = did_key_for(&SigningKey::from_bytes(&[11; 32]).verifying_key());
    let assertion = assertion.trim_start_matches("did:key:");
    let auth = auth.trim_start_matches("did:key:");
    let service = base64_url(br#"{"t":"LinkedDomains","s":"https://peer.example/"}"#);
    let did = format!("did:peer:2.A{assertion}.V{auth}.S{service}");

    let doc = resolver_with(StaticTransport::default()).resolve(&did).unwrap();
    assert_eq!(doc.id.as_str(), did);
    assert_eq!(key_multibase(&doc, &format!("{did}#key-1")), assertion);
    assert_eq!(key_multibase(&doc, &format!("{did}#key-2")), auth);
    assert_eq!(doc.assertion_method.len(), 1);
    assert_eq!(doc.authentication.len(), 1);
    assert_eq!(doc.service.len(), 1);
    assert_eq!(doc.service[0].type_, vec!["LinkedDomains".to_string()]);
    assert_eq!(doc.service[0].service_endpoint.get_uri().as_deref(), Some("https://peer.example/"));
}

#[test]
fn did_peer_with_an_unknown_numalgo_is_rejected() {
    let err = resolver_with(StaticTransport::default()).resolve("did:peer:4zQmd8").unwrap_err();
    assert!(matches!(err, ResolveError::InvalidDid(_)), "{err:?}");
}

// --- did:web -------------------------------------------------------------

#[test]
fn did_web_maps_a_bare_domain_to_the_well_known_path() {
    assert_eq!(
        did_web_url("did:web:members.harbourclub.example").unwrap(),
        "https://members.harbourclub.example/.well-known/did.json"
    );
}

#[test]
fn did_web_maps_path_segments_and_an_encoded_port() {
    assert_eq!(
        did_web_url("did:web:guild.example:chapters:north").unwrap(),
        "https://guild.example/chapters/north/did.json"
    );
    assert_eq!(
        did_web_url("did:web:localhost%3A8443:issuers:1").unwrap(),
        "https://localhost:8443/issuers/1/did.json"
    );
}

#[test]
fn did_web_rejects_an_empty_host() {
    assert!(did_web_url("did:web:").is_err());
}

#[test]
fn did_web_fetches_the_hosted_document() {
    let doc = resolver_with(transport()).resolve(HARBOUR_DID).unwrap();
    assert_eq!(doc.id.as_str(), HARBOUR_DID);
    assert_eq!(key_multibase(&doc, HARBOUR_KEY_ID), HARBOUR_PUBLIC);
    assert_eq!(doc.service[0].service_endpoint.get_uri().as_deref(), Some("https://harbourclub.example/"));
}

#[test]
fn did_web_rejects_a_document_for_another_did() {
    let mut doc = harbour_document();
    doc["id"] = json!("did:web:someone-else.example");
    let transport = StaticTransport::default().with(HARBOUR_URL, doc.to_string());
    let err = resolver_with(transport).resolve(HARBOUR_DID).unwrap_err();
    assert!(matches!(err, ResolveError::DocumentMismatch { .. }), "{err:?}");
}

#[test]
fn did_web_reports_a_missing_document() {
    let err = resolver_with(StaticTransport::default()).resolve(HARBOUR_DID).unwrap_err();
    assert!(matches!(err, ResolveError::Transport(_)), "{err:?}");
}

#[test]
fn mirror_transport_serves_documents_from_its_root() {
    let root = std::env::temp_dir().join(format!("did-mirror-{}", std::process::id()));
    let dir = root.join("members.harbourclub.example/.well-known");
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join("did.json"), harbour_document().to_string()).unwrap();

    let mirror = MirrorTransport::new(&root);
    let body = mirror.get("https://members.harbourclub.example/.well-known/did.json").unwrap();
    assert_eq!(serde_json::from_slice::<serde_json::Value>(&body).unwrap()["id"], HARBOUR_DID);
    assert!(mirror.get("https://members.harbourclub.example/../../etc/passwd").is_err());
    assert!(mirror.get("http://members.harbourclub.example/.well-known/did.json").is_err());

    std::fs::remove_dir_all(&root).unwrap();
}

// --- other methods ------------------------------------------------------

#[test]
fn unsupported_methods_are_reported() {
    let err = resolver_with(StaticTransport::default()).resolve("did:ion:EiClkZMDxPKqC9c").unwrap_err();
    assert!(matches!(err, ResolveError::UnsupportedMethod(ref m) if m == "ion"), "{err:?}");
    assert!(matches!(
        resolver_with(StaticTransport::default()).resolve("not-a-did").unwrap_err(),
        ResolveError::InvalidDid(_)
    ));
}

fn base64_url(bytes: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes)
}
