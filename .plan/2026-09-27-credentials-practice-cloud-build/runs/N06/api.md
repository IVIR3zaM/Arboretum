# N06 — backend API & wire contract (consumed by N07 app, N09 notifier, N10 grader)

Crate: `practices/credentials/backend` (`credentials-backend`, lib `credentials_backend`), Rust 1.98.1,
`cargo test --offline --locked` green (58 tests). All paths below are relative to
`practices/credentials/`. Line numbers are as shipped by N06.

## 1. Wire contract

All timestamps are **integer unix seconds**. All signatures are Ed25519 over the **RFC 8785 (JCS)**
bytes of the document with its top-level `proof` member removed (`credential::signing_input`).
The JCS implementation (`backend/src/credential.rs:82-131`) sorts object keys by UTF-16 code units,
uses minimal JSON string escaping, and writes integral numbers without a fraction. Claim values
should be strings, integers, booleans, null, arrays or objects of those (non-integral floats are
written with Rust's `{}` formatting, which only matches ECMAScript for "simple" values — avoid them).

### 1.1 Proof object (VC and VP)

```json
"proof": {
  "type": "Ed25519Signature2020",
  "created": 1780272000,
  "verificationMethod": "<DID URL of the signing key>",
  "proofPurpose": "assertionMethod" | "authentication",
  "proofValue": "z<base58btc of the 64-byte Ed25519 signature>"
}
```
The proof object itself is **not** covered by the signature. `proofValue` is multibase base58btc
(`z` prefix, Bitcoin alphabet), no multicodec header.

### 1.2 Verifiable Credential (issuer → holder)

```json
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "id": "urn:uuid:<v4>",
  "type": ["VerifiableCredential", "MembershipCredential"],
  "issuer": "did:web:members.harbourclub.example",
  "issued_at": 1777680000,
  "not_before": 1777680000,
  "expires_at": 1795824000,
  "credentialSubject": {
    "id": "did:key:z6Mk...",                 // the holder DID (always did:key)
    "_sd": ["<digest>", "<digest>", ...]     // sorted; claim values are NOT in the VC
  },
  "credentialStatus": {
    "type": "StatusListEntry",
    "statusListId": "<issuer DID>#revocation",
    "statusListIndex": 1                     // integer
  },
  "proof": { ... "proofPurpose": "assertionMethod", "verificationMethod": "<issuer DID>#<frag>" }
}
```
The expiry field is **`expires_at`** (the README's `expirationDate` is FM-15 drift).

### 1.3 Disclosures (issuer → holder only)

The holder receives the VC **plus** one disclosure per claim:
```json
{ "salt": "<base64url, 16 random bytes, no padding>", "name": "member", "value": true }
```
`digest = base64url_nopad( SHA-256( UTF-8( JCS( [salt, name, value] ) ) ) )` — a JSON **array**
of the three members in that order, canonicalized. Test vector
(`backend/tests/credential.rs:32-37`): salt `c2FsdA`, name `member`, value `true` →
JCS `["c2FsdA","member",true]` → digest `c-ZiuLoNN9HMsfOE2LQWHZNCZJLLnzaxRm_5gNAPlR8`.

### 1.4 Verifiable Presentation (holder → verifier)

```json
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "type": ["VerifiablePresentation"],
  "holder": "did:key:z6Mk...",
  "verifiableCredential": { <the VC exactly as issued, with its proof> },
  "disclosures": [ { "salt": ..., "name": ..., "value": ... }, ... ],   // the chosen subset
  "nonce": "<verifier nonce>",
  "domain": "<verifier domain>",
  "proof": {
    "type": "Ed25519Signature2020", "created": <int>,
    "verificationMethod": "did:key:z6Mk...#z6Mk...",   // did:key VM id = "<did>#<multibase>"
    "proofPurpose": "authentication",
    "proofValue": "z..."
  }
}
```
The holder proof covers JCS of the whole VP minus `proof` (so it covers the VC, the disclosures,
the nonce and the domain). Holder DIDs are `did:key` (Ed25519 multikey, `z6Mk...`).

### 1.5 What the verifier checks, in order (`Verifier::verify_presentation`, verifier.rs:104-152)
1. replay guard on `Submission.request_id` (latent #1) → `Replay`
2. `vp.nonce == expected_nonce` → else `NonceMismatch`; `vp.domain == expected_domain` → else `DomainMismatch`
3. holder proof against the holder DID's `authentication` key → `BadSignature` / `UnknownKey`
4. `verify_credential(vc)` (below)
5. `vc.credentialSubject.id == vp.holder` → else `HolderMismatch`
6. each disclosure's digest ∈ `vc.credentialSubject._sd` → else `UndisclosedClaim(name)`; disclosed claims returned

`Verifier::verify_credential` (verifier.rs:155-193): `resolve_issuer(issuer)` → issuer proof against a key
listed in `assertionMethod` (`UnknownKey(vm)` if the proof's `verificationMethod` is not listed,
`BadSignature` if it is listed but the signature fails) → `not_before`/`expires_at` window
(`NotYetValid` / `Expired`) → status bit (`Revoked`; `UnknownStatus(list)` if the list is not in the store).

## 2. Public entry points (Rust)

```rust
// resolver.rs
pub struct Resolver;                                           // Clone
impl Resolver {
    pub fn new(transport: Arc<dyn DocumentTransport>) -> Self;
    pub fn resolve(&self, did: &str) -> Result<affinidi_did_common::Document, ResolveError>;
}                                                              // did:key, did:peer:0, did:peer:2, did:web
pub fn did_web_url(did: &str) -> Result<String, ResolveError>; // spec §3.2 mapping incl. paths and %3A ports
pub fn did_key_for(key: &ed25519_dalek::VerifyingKey) -> String;
pub enum ResolveError { InvalidDid(String), UnsupportedMethod(String), Transport(TransportError),
                        InvalidDocument{did,reason}, DocumentMismatch{did,found} }

// transport.rs — injecting a transport
pub trait DocumentTransport: Send + Sync { fn get(&self, url: &str) -> Result<Vec<u8>, TransportError>; }
pub struct MirrorTransport;   // new(root) | from_env(): $DID_MIRROR_ROOT or <crate>/../reference/infra/hosted-dids
                              // serves https://<authority>/<path> from <root>/<authority>/<path>; https only
pub struct StaticTransport;   // Default + .with(url, body): in-memory, for tests

// verifier.rs
pub struct Submission { pub request_id: String, pub presentation: serde_json::Value }
pub struct Verifier;
impl Verifier {
    pub fn new(resolver: Resolver, store: Arc<Store>) -> Self;
    pub fn with_clock(self, clock: impl Fn() -> i64 + Send + Sync + 'static) -> Self;   // unix seconds
    pub fn verify_presentation(&self, submission: &Submission, expected_nonce: &str, expected_domain: &str)
        -> Result<VerifiedPresentation, VerifyError>;
    pub fn verify_credential(&self, vc: &serde_json::Value) -> Result<VerifiedCredential, VerifyError>;
    pub fn resolve_issuer(&self, did: &str) -> Result<Document, VerifyError>;            // the Ticket-1 root
}
pub struct VerifiedCredential { pub id, pub issuer, pub subject: String, pub expires_at: i64,
                                pub issuer_site: Option<String> }   // issuer doc's LinkedDomains endpoint
pub struct VerifiedPresentation { pub holder: String, pub credential: VerifiedCredential,
                                  pub claims: BTreeMap<String, Value> }
pub enum VerifyError { Malformed(String), Replay, NonceMismatch, DomainMismatch, HolderMismatch,
    Resolve(ResolveError), UnknownKey(String), BadSignature(String), Expired, NotYetValid, Revoked,
    UnknownStatus(String), UndisclosedClaim(String) }

// issuer.rs
pub fn onboard(resolver: &Resolver, store: &Store, did: &str, name: &str, onboarded_at: &str)
    -> Result<OnboardedIssuer, OnboardError>;        // the working did:web fetch path (resolver.resolve)
pub struct Issuer;
impl Issuer {
    pub fn new(did: &str, verification_method: &str, seed: &[u8; 32]) -> Self;
    pub fn issue(&self, store: &Store, request: &CredentialRequest) -> Result<IssuedCredential, IssueError>;
    pub fn did(&self) -> &str; pub fn verifying_key(&self) -> VerifyingKey; pub fn status_list(&self) -> String;
}
pub struct CredentialRequest { pub holder: String, pub credential_type: String,
    pub claims: Vec<(String, Value)>, pub issued_at: i64, pub not_before: Option<i64>, pub expires_at: i64 }
pub struct IssuedCredential { pub credential: Value, pub disclosures: Vec<Disclosure> }

// credential.rs
pub struct Disclosure { pub salt: String, pub name: String, pub value: Value }  // Serialize/Deserialize
impl Disclosure { pub fn new(name, value) -> Self; pub fn digest(&self) -> String; }
pub fn canonicalize(value: &Value) -> String;       // JCS
pub fn signing_input(document: &Value) -> Vec<u8>;  // JCS bytes without "proof"
pub fn sign(document: &mut Value, key: &SigningKey, verification_method: &str, purpose: &str, created: i64);
pub fn verify_signature(document: &Value, key: &VerifyingKey) -> Result<(), String>;
pub const ED25519_SIGNATURE_2020: &str;

// status.rs
pub fn revoke_credential(store: &Store, credential_id: &str) -> Result<StatusChange, StatusError>;
pub struct StatusChange { pub credential_id, pub issuer, pub status_list: String, pub status_index: usize, pub revoked: bool }
pub struct StatusList;  // new(capacity), allocate, set, is_set, encode, decode; DEFAULT_CAPACITY = 131_072

// store.rs
pub struct Store;       // interior Mutex; share as Arc<Store>
impl Store { new(); from_onboarding_data() /* data/onboarded-issuers.json, include_str! */;
    record_onboarded_issuer; onboarded_issuer(did) -> Option<OnboardedIssuer>; onboarded_issuers();
    record_credential; credential(id); allocate_status_index(list); set_status(list, index, revoked) -> bool;
    is_revoked(list, index) -> Option<bool>; encoded_status_list(list) }
```

**Production wiring (what the grade harness should build):**
```rust
let store = Arc::new(Store::from_onboarding_data()?);
let resolver = Resolver::new(Arc::new(MirrorTransport::from_env()));   // or MirrorTransport::new(<practice>/reference/infra/hosted-dids)
let verifier = Verifier::new(resolver, store.clone()).with_clock(|| NOW);
// sign as any issuer: Issuer::new(did, vm_id, &seed).issue(&store, &request) — allocates a status entry in `store`
```
Issuing into the **same** `store` the verifier uses is required, otherwise `verify_credential`
returns `UnknownStatus`. The module layout leaves room for `src/notifier.rs` (N09): add
`pub mod notifier;` to `src/lib.rs`; hook it on `status::revoke_credential`'s `StatusChange`.

## 3. Ticket 1 — the stale path

`backend/src/verifier.rs:197-205`, `Verifier::resolve_issuer`: for any issuer in
`store.onboarded_issuer(did)` (all four onboarded issuers are did:web) it returns the document
recorded at onboarding (`backend/data/onboarded-issuers.json`) instead of calling
`self.resolver.resolve(did)`, which does the real did:web fetch through the transport.
The working fetch path already exists: `Resolver::resolve_web` (resolver.rs:61-71), used by
`issuer::onboard` (issuer.rs:20-38) and by `resolve_issuer` for non-onboarded DIDs.

Reference fix (verified in a temp copy, `runs/N06/t1-demo.txt`): delete verifier.rs:198-203
(the "peer DIDs" comment and the `if let Some(issuer) = self.store.onboarded_issuer(did)` early
return), leaving `Ok(self.resolver.resolve(did)?)`. The visible suite stays green after the fix
(its verifier transport serves Harbour's published document, `backend/tests/common/mod.rs`).

Issuer states (onboarding snapshot vs `reference/infra/hosted-dids/`; keys in
`_solutions/fixtures/issuer-keys.json`):

| Issuer DID | State | Hosted object | Failure with the bug |
|---|---|---|---|
| `did:web:members.harbourclub.example` | never rotated (snapshot == hosted) | `members.harbourclub.example/.well-known/did.json` | accepted |
| `did:web:issuer.cedarrowing.example` | rotated key, new id `#key-1`→`#key-2` | `issuer.cedarrowing.example/.well-known/did.json` | `UnknownKey` |
| `did:web:guild.northfield.example:chapters:north` | rotated key, **same** id `#signing` (path-based DID) | `guild.northfield.example/chapters/north/did.json` | `BadSignature` |
| `did:web:badges.kestrel-league.example` | rotated key `#key-2025`→`#key-2026` **and** LinkedDomains endpoint moved (`https://badges.kestrel-league.example/` → `https://kestrel-league.example/members/`) | `badges.kestrel-league.example/.well-known/did.json` | `UnknownKey`; `issuer_site`/`resolve_issuer` service endpoint stale |

Harbour Club's seed lives only in `backend/tests/common/mod.rs:21` (`HARBOUR_SEED`); the rotated
issuers' current and onboarding-time seeds live only in `_solutions/fixtures/issuer-keys.json`.
A re-pin plateau: patching one issuer's record in `data/onboarded-issuers.json` fixes that issuer only.

## 4. FM-15 drift (all written as belief)

| Item | Where | Truth |
|---|---|---|
| "We identify issuers with `did:key`" (no lookup, no network) | `backend/README.md:8-10` | issuers are did:web (`data/onboarded-issuers.json`, `reference/`) |
| `expirationDate` field | `backend/README.md:23` | code uses `expires_at` (issuer.rs:132, verifier.rs:165) |
| "Credentials are single-use" | `backend/README.md:32-33` | not enforced; only a request-id replay guard exists |
| "peer DIDs" comment | `backend/src/verifier.rs:198-200` | sits on the stale path; did:web documents are not self-contained |

## 5. Planted latents (not tested by the suite; no graded case needs them fixed)

| # | FM | Where | Defect |
|---|---|---|---|
| 1 | FM-06 | `backend/src/verifier.rs:111` | replay guard keyed on the transport `Submission.request_id`, not the VP `nonce`: the same VP with a fresh request id is accepted (nonce/domain still checked) |
| 3 | FM-07 | `backend/src/verifier.rs:73-81` | `ReplayGuard.seen_nonces` grows without bound (never pruned) |
| 4 | FM-04 | `backend/src/verifier.rs:166-171` | `now < not_before` / `now > expires_at`: at exactly `expires_at` the credential is still accepted; boundary unspecified and untested |
| 5 | FM-03 | `backend/src/status.rs:35-41` | `allocate` pre-increments: indexes run 1..=capacity, bit 0 is never used, and the last index (== capacity) is outside the bitstring, so `set` silently ignores it — that credential can never be revoked (and every published bit is shifted from its "first allocated" position) |
| 6 | FM-08 | `backend/src/verifier.rs:155-161` | no trust-registry query anywhere: any issuer whose DID resolves and whose signature verifies is accepted (e.g. a self-issued `did:key` issuer). `reference/trust-registry.md` requires a live `POST /authorization` check |
| 7 | FM-03 | `backend/src/verifier.rs:211` and `:122-126` | a proof whose `type` is not `Ed25519Signature2020` is not checked at all (falls through to `Ok`); a VP holder on an unsupported DID method skips the holder-proof check |

#2 belongs to the app (N07). #8 (HashMap canonicalization) is **not** planted: JCS is correct
cross-stack.

For N10: replay cases must use a nonce or domain mismatch (not a fresh request id); expiry cases
must not sit exactly on `expires_at`; revocation cases work for any index a real issuance returns
(the out-of-range index is only the last one of a 131 072-bit list); trust (#6) never interferes
because all four graded issuers are registry-active.
