//! Axis (a) — Ticket 1 hidden acceptance: issuer did:web resolution on the
//! verification side.
//!
//! Root-tested: every case calls `Verifier::verify_credential` or
//! `Verifier::resolve_issuer` directly. The presentation handler
//! (`verify_presentation`) is never called, so a fix at the call site does
//! not move this axis.
//!
//! Four groups, graded worst-case (every case must pass):
//!
//! - **S** issuer states as hosted in `reference/infra/hosted-dids/`: never
//!   rotated, rotated key (new id), rotated key (same id, path-based DID),
//!   rotated key + moved LinkedDomains endpoint.
//! - **R** retired keys: a key no longer in the served document is not a key
//!   of the DID (`reference/did-web-method.md` §4).
//! - **V** conformance vectors derived from `reference/`: the resolved issuer
//!   document is the hosted one (§3.2 + hosted-dids), id mismatch fails
//!   (§3.2 step 8), a removed document fails (§3.4), ported hosts (§3.2 table).
//! - **N** a grader-only "next rotation": documents newer than anything in
//!   `reference/`, served only by this grader's transport. Re-pinning an
//!   onboarding snapshot or hard-coding a key from `reference/` plateaus here.
//!
//! Every scenario builds a fresh `Verifier` over a fresh transport, so the
//! axis grades where the document comes from, not whether it is cached.
//! Credentials are signed with the keys in `_solutions/fixtures/issuer-keys.json`.

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use credentials_backend::issuer::{CredentialRequest, Issuer};
use credentials_backend::resolver::{did_key_for, did_web_url, Resolver};
use credentials_backend::store::Store;
use credentials_backend::transport::{DocumentTransport, MirrorTransport, TransportError};
use credentials_backend::verifier::{VerifiedCredential, VerifyError, Verifier};
use ed25519_dalek::SigningKey;
use serde_json::{json, Value};

/// 2026-06-01T00:00:00Z.
const NOW: i64 = 1_780_272_000;
const DAY: i64 = 86_400;

/// Harbour Club never rotated; its seed is only in the visible suite
/// (`backend/tests/common/mod.rs`, `HARBOUR_SEED`) and is copied here so the
/// grader does not depend on a file the learner may edit.
const HARBOUR_SEED: &str = "9f3688f6e8b93b0cfa3b11c28fbc25fe5440192ed82835e7fe3ab590f03f6c75";

const HARBOUR: &str = "did:web:members.harbourclub.example";
const CEDAR: &str = "did:web:issuer.cedarrowing.example";
const NORTHFIELD: &str = "did:web:guild.northfield.example:chapters:north";
const KESTREL: &str = "did:web:badges.kestrel-league.example";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

fn practice_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn hosted_root() -> PathBuf {
    practice_root().join("reference/infra/hosted-dids")
}

fn seed(hex: &str) -> [u8; 32] {
    let mut out = [0u8; 32];
    for (i, byte) in out.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).expect("hex seed");
    }
    out
}

#[derive(Clone)]
struct Key {
    vm: String,
    seed: [u8; 32],
}

impl Key {
    fn multibase(&self) -> String {
        let did = did_key_for(&SigningKey::from_bytes(&self.seed).verifying_key());
        did.trim_start_matches("did:key:").to_string()
    }
}

struct Keys {
    current: HashMap<String, Key>,
    onboarded: HashMap<String, Key>,
}

fn load_keys() -> Keys {
    let path = practice_root().join("_solutions/fixtures/issuer-keys.json");
    let text = std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("reading {}: {e}", path.display()));
    let fixtures: Value = serde_json::from_str(&text).expect("issuer-keys.json parses");
    let mut keys = Keys { current: HashMap::new(), onboarded: HashMap::new() };
    for issuer in fixtures["issuers"].as_array().expect("issuers") {
        let did = issuer["did"].as_str().expect("did").to_string();
        for (slot, map) in [("current", &mut keys.current), ("onboarded", &mut keys.onboarded)] {
            let entry = &issuer[slot];
            if entry.is_null() {
                continue;
            }
            let vm = entry["verificationMethod"].as_str().expect("verificationMethod").to_string();
            let hex = entry["seed"].as_str().unwrap_or(HARBOUR_SEED);
            map.insert(did.clone(), Key { vm, seed: seed(hex) });
        }
    }
    keys
}

/// A grader-only key, not present anywhere in the practice.
fn fresh_key(did: &str, fragment: &str, byte: u8) -> Key {
    Key { vm: format!("{did}#{fragment}"), seed: [byte; 32] }
}

/// A did:web document in the shape the hosting bucket serves.
fn document(did: &str, keys: &[&Key], site: &str) -> Value {
    let methods: Vec<Value> = keys
        .iter()
        .map(|k| json!({ "id": k.vm, "type": "Multikey", "controller": did, "publicKeyMultibase": k.multibase() }))
        .collect();
    let ids: Vec<&str> = keys.iter().map(|k| k.vm.as_str()).collect();
    json!({
        "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
        "id": did,
        "verificationMethod": methods,
        "authentication": ids,
        "assertionMethod": ids,
        "service": [{ "id": format!("{did}#site"), "type": "LinkedDomains", "serviceEndpoint": site }]
    })
}

fn hosted_document(did: &str) -> Value {
    let url = did_web_url(did).expect("did:web url");
    let body = MirrorTransport::new(hosted_root()).get(&url).unwrap_or_else(|e| panic!("hosted {did}: {e}"));
    serde_json::from_slice(&body).expect("hosted document parses")
}

// ---------------------------------------------------------------------------
// The grader's transport: the hosted bucket copy, with per-scenario overrides
// ---------------------------------------------------------------------------

struct GraderTransport {
    mirror: MirrorTransport,
    /// `Some(body)` serves `body`; `None` serves nothing (document removed).
    overrides: HashMap<String, Option<Vec<u8>>>,
}

impl GraderTransport {
    fn hosted() -> Self {
        GraderTransport { mirror: MirrorTransport::new(hosted_root()), overrides: HashMap::new() }
    }

    fn serve(mut self, did: &str, document: &Value) -> Self {
        self.overrides.insert(did_web_url(did).expect("did:web url"), Some(document.to_string().into_bytes()));
        self
    }

    fn serve_at(mut self, url: &str, document: &Value) -> Self {
        self.overrides.insert(url.to_string(), Some(document.to_string().into_bytes()));
        self
    }

    fn remove(mut self, did: &str) -> Self {
        self.overrides.insert(did_web_url(did).expect("did:web url"), None);
        self
    }
}

impl DocumentTransport for GraderTransport {
    fn get(&self, url: &str) -> Result<Vec<u8>, TransportError> {
        match self.overrides.get(url) {
            Some(Some(body)) => Ok(body.clone()),
            Some(None) => Err(TransportError::NotFound(url.to_string())),
            None => self.mirror.get(url),
        }
    }
}

/// A fresh verifier and its store, wired like production (onboarding data +
/// a transport), with `transport` standing in for the document bucket.
fn setup(transport: GraderTransport) -> (Verifier, Arc<Store>) {
    let store = Arc::new(Store::from_onboarding_data().expect("onboarding data parses"));
    let resolver = Resolver::new(Arc::new(transport));
    (Verifier::new(resolver, store.clone()).with_clock(|| NOW), store)
}

fn credential(store: &Store, issuer_did: &str, key: &Key) -> Value {
    let holder = did_key_for(&SigningKey::from_bytes(&[0x42; 32]).verifying_key());
    let request = CredentialRequest {
        holder,
        credential_type: "MembershipCredential".into(),
        claims: vec![("member".into(), json!(true)), ("tier".into(), json!("gold"))],
        issued_at: NOW - 10 * DAY,
        not_before: None,
        expires_at: NOW + 180 * DAY,
    };
    Issuer::new(issuer_did, &key.vm, &key.seed).issue(store, &request).expect("issue").credential
}

// ---------------------------------------------------------------------------
// Expectations
// ---------------------------------------------------------------------------

type Outcome = Result<(), String>;

fn accepted(result: Result<VerifiedCredential, VerifyError>, site: Option<&str>) -> Outcome {
    match result {
        Ok(vc) => match site {
            Some(site) if vc.issuer_site.as_deref() != Some(site) => {
                Err(format!("accepted, but issuer_site is {:?}, expected {site:?}", vc.issuer_site))
            }
            _ => Ok(()),
        },
        Err(e) => Err(format!("rejected: {e} ({e:?})")),
    }
}

fn rejected(result: Result<VerifiedCredential, VerifyError>) -> Outcome {
    match result {
        Ok(_) => Err("accepted; must be rejected".into()),
        Err(_) => Ok(()),
    }
}

/// Verifies a credential signed with `key` against the served documents.
fn verify_with(transport: GraderTransport, issuer: &str, key: &Key) -> Result<VerifiedCredential, VerifyError> {
    let (verifier, store) = setup(transport);
    let vc = credential(&store, issuer, key);
    verifier.verify_credential(&vc)
}

/// The parts of a DID document verification depends on: the assertion keys
/// (id → public key) and the LinkedDomains endpoints.
fn essentials(doc: &Value) -> (BTreeMap<String, String>, BTreeSet<String>) {
    let did = doc["id"].as_str().unwrap_or_default().to_string();
    let absolute = |id: &str| match id.strip_prefix('#') {
        Some(fragment) => format!("{did}#{fragment}"),
        None => id.to_string(),
    };
    let methods: HashMap<String, String> = doc["verificationMethod"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|vm| Some((absolute(vm["id"].as_str()?), vm["publicKeyMultibase"].as_str()?.to_string())))
        .collect();
    let mut keys = BTreeMap::new();
    for entry in doc["assertionMethod"].as_array().into_iter().flatten() {
        match entry {
            Value::String(id) => {
                let id = absolute(id);
                let key = methods.get(&id).cloned().unwrap_or_default();
                keys.insert(id, key);
            }
            Value::Object(_) => {
                let id = absolute(entry["id"].as_str().unwrap_or_default());
                keys.insert(id, entry["publicKeyMultibase"].as_str().unwrap_or_default().to_string());
            }
            _ => {}
        }
    }
    let mut sites = BTreeSet::new();
    for service in doc["service"].as_array().into_iter().flatten() {
        let linked = match &service["type"] {
            Value::String(t) => t == "LinkedDomains",
            Value::Array(ts) => ts.iter().any(|t| t == "LinkedDomains"),
            _ => false,
        };
        if linked {
            match &service["serviceEndpoint"] {
                Value::String(uri) => {
                    sites.insert(uri.clone());
                }
                other => {
                    sites.insert(other.to_string());
                }
            }
        }
    }
    (keys, sites)
}

/// `resolve_issuer(did)` must return the document hosted for `did`.
fn resolves_to_hosted(did: &str) -> Outcome {
    let (verifier, _) = setup(GraderTransport::hosted());
    let resolved = verifier.resolve_issuer(did).map_err(|e| format!("resolve_issuer failed: {e}"))?;
    let resolved = serde_json::to_value(&resolved).map_err(|e| format!("serializing resolved document: {e}"))?;
    let (want_keys, want_sites) = essentials(&hosted_document(did));
    let (got_keys, got_sites) = essentials(&resolved);
    if got_keys != want_keys {
        return Err(format!("assertion keys {got_keys:?}, hosted document has {want_keys:?}"));
    }
    if got_sites != want_sites {
        return Err(format!("LinkedDomains {got_sites:?}, hosted document has {want_sites:?}"));
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

fn main() {
    let keys = load_keys();
    let current = |did: &str| keys.current.get(did).cloned().unwrap_or_else(|| panic!("no current key for {did}"));
    let onboarded = |did: &str| keys.onboarded.get(did).cloned().unwrap_or_else(|| panic!("no onboarded key for {did}"));
    let hosted = GraderTransport::hosted;

    let mut cases: Vec<(&str, String, Outcome)> = Vec::new();
    let mut case = |id: &'static str, name: &str, outcome: Outcome| cases.push((id, name.to_string(), outcome));

    // S — issuer states as hosted in reference/infra/hosted-dids/.
    case("S1", "never rotated (Harbour Club): current key accepted",
        accepted(verify_with(hosted(), HARBOUR, &current(HARBOUR)), Some("https://harbourclub.example/")));
    case("S2", "rotated key, new id #key-2 (Cedar Rowing): current key accepted",
        accepted(verify_with(hosted(), CEDAR, &current(CEDAR)), Some("https://cedarrowing.example/")));
    case("S3", "rotated key, same id #signing, path DID (Northfield): current key accepted",
        accepted(verify_with(hosted(), NORTHFIELD, &current(NORTHFIELD)), Some("https://guild.northfield.example/")));
    case("S4", "rotated key + moved endpoint (Kestrel): current key accepted, current issuer site",
        accepted(verify_with(hosted(), KESTREL, &current(KESTREL)), Some("https://kestrel-league.example/members/")));

    // R — keys retired by rotation are no longer keys of the DID (method spec §4).
    case("R1", "Cedar Rowing: retired #key-1 rejected", rejected(verify_with(hosted(), CEDAR, &onboarded(CEDAR))));
    case("R2", "Northfield: retired #signing material rejected",
        rejected(verify_with(hosted(), NORTHFIELD, &onboarded(NORTHFIELD))));
    case("R3", "Kestrel: retired #key-2025 rejected", rejected(verify_with(hosted(), KESTREL, &onboarded(KESTREL))));

    // V — conformance vectors derived from reference/.
    for (id, did) in [("V1", HARBOUR), ("V2", CEDAR), ("V3", NORTHFIELD), ("V4", KESTREL)] {
        case(id, &format!("resolve_issuer({did}) is the hosted did.json (keys + LinkedDomains)"), resolves_to_hosted(did));
    }
    case("V5", "document whose id is not the DID fails resolution (spec §3.2 step 8)", {
        // Harbour's own key and site, published under another DID's id.
        let foreign = document("did:web:members.harbourclub.example:elsewhere", &[&current(HARBOUR)], "https://harbourclub.example/");
        rejected(verify_with(hosted().serve(HARBOUR, &foreign), HARBOUR, &current(HARBOUR)))
    });
    case("V6", "deactivated issuer (document removed) fails resolution (spec §3.4)",
        rejected(verify_with(hosted().remove(HARBOUR), HARBOUR, &current(HARBOUR))));
    case("V7", "ported host did:web:example.com%3A3000:user:alice resolves at host:3000 (spec §3.2)", {
        let did = "did:web:example.com%3A3000:user:alice";
        let key = fresh_key(did, "key-1", 0x51);
        let doc = document(did, &[&key], "https://example.com:3000/alice/");
        let transport = hosted().serve_at("https://example.com:3000/user/alice/did.json", &doc);
        accepted(verify_with(transport, did, &key), Some("https://example.com:3000/alice/"))
    });

    // N — the next rotation: newer than anything in reference/, served only here.
    {
        let next = fresh_key(HARBOUR, "key-2", 0xA1);
        let doc = document(HARBOUR, &[&next], "https://harbourclub.example/");
        case("N1", "Harbour Club rotates for the first time: new #key-2 accepted",
            accepted(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &next), None));
        case("N2", "Harbour Club rotates for the first time: retired #key-1 rejected",
            rejected(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &current(HARBOUR))));
    }
    {
        let next = fresh_key(CEDAR, "key-3", 0xA2);
        let doc = document(CEDAR, &[&next], "https://cedarrowing.example/");
        case("N3", "Cedar Rowing rotates again: new #key-3 accepted",
            accepted(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &next), None));
        case("N4", "Cedar Rowing rotates again: #key-2 retired and rejected",
            rejected(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &current(CEDAR))));
    }
    {
        let next = Key { vm: current(NORTHFIELD).vm, seed: [0xA3; 32] };
        let doc = document(NORTHFIELD, &[&next], "https://guild.northfield.example/");
        case("N5", "Northfield rotates #signing again: new material accepted",
            accepted(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &next), None));
        case("N6", "Northfield rotates #signing again: previous material rejected",
            rejected(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &current(NORTHFIELD))));
    }
    {
        let next = fresh_key(KESTREL, "key-2027", 0xA4);
        let doc = document(KESTREL, &[&next], "https://kestrel-league.example/clubs/");
        case("N7", "Kestrel rotates key and moves its site again: accepted with the newest site",
            accepted(verify_with(hosted().serve(KESTREL, &doc), KESTREL, &next), Some("https://kestrel-league.example/clubs/")));
    }

    let total = cases.len();
    let mut passed = 0;
    for (id, name, outcome) in &cases {
        match outcome {
            Ok(()) => {
                passed += 1;
                println!("ok   {id} {name}");
            }
            Err(reason) => println!("FAIL {id} {name}: {reason}"),
        }
    }
    let verdict = if passed == total { "PASS" } else { "FAIL" };
    println!("axis a: {verdict} {passed}/{total}");
    std::process::exit(if passed == total { 0 } else { 1 });
}
