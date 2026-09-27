//! Smoke test: builds a DID Document type from `affinidi-did-common`.
//!
//! This proves the crate is a real, pinned, non-vendored dependency (FM-08) and
//! that it supplies DID / DID-Document *types* only — no resolver behaviour is
//! exercised here.

use affinidi_did_common::Document;

#[test]
fn builds_a_did_document_from_affinidi_did_common() {
    let doc = Document::new("did:example:123456789abcdefghi").expect("valid did url");
    assert_eq!(doc.id.as_str(), "did:example:123456789abcdefghi");
    assert!(doc.verification_method.is_empty());
}
