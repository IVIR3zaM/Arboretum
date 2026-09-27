# N21 — Ticket 1 plant: a path-DID mapping gap only reference/ reveals (2026-09-27)

## The plant
- `practices/credentials/backend/src/resolver.rs:94-100` (`did_web_url`): every DID's URL is built
  under `https://<host>/.well-known`, then any path segments, then `/did.json`. A bare-domain DID
  (with or without `%3A` port) still maps to `https://<host>[:port]/.well-known/did.json` (§3.2).
  A path DID maps to `https://<host>/.well-known/<p1>/<p2>/did.json`; §3.2 gives
  `https://<host>/<p1>/<p2>/did.json`. Northfield resolves to
  `https://guild.northfield.example/.well-known/chapters/north/did.json`, which the bucket mirror
  does not hold, so resolution fails with `Transport(NotFound)`.
- Doc comment `resolver.rs:78-81` now describes the planted behaviour as intended ("`did.json`
  under the host's `/.well-known/` directory, with any further segments of the identifier as
  subdirectories"). It does not state the §3.2 mapping.
- Visible suite: `backend/tests/resolver.rs:97-100` `did_web_maps_an_encoded_port`
  (`did:web:localhost%3A8443` → `https://localhost:8443/.well-known/did.json`) replaces
  `did_web_maps_path_segments_and_an_encoded_port`. No visible test uses a path-segment DID.
- Onboarding snapshot `backend/data/onboarded-issuers.json` unchanged (the stale early return
  still hides the gap on the planted tree).

## The drift comment
- Moved from `verifier.rs:198-200` (on the early return) to `practices/credentials/backend/src/store.rs:68-70`,
  the doc comment of `Store::onboarded_issuer`. Wording unchanged ("Issuer documents are
  self-contained, as with the peer DIDs issuers first onboarded with: ..."), FM-15 item "peer DIDs".
- `verifier.rs:196-202` `resolve_issuer` now has only its one-line doc comment above the early return.

## Grader (axis a) — `_solutions/grader/src/main.rs`
- `did_web_url` is no longer used to decide where a document lives. The grader-local `spec_url`
  (§3.2 steps 1-6, own percent-decoding) now drives `hosted_document`, `GraderTransport::serve` and
  `GraderTransport::remove`. `did_web_url` is only imported to be tested by the W cases.
- Every case runs under `catch_unwind` (panic hook silenced). A panic prints as
  `FAIL <id> ...: panicked: <msg>`. Every case prints its own line, and `axis a:` is always last.

| id | status | expectation |
|---|---|---|
| W1 | new | `did_web_url("did:web:w3c-ccg.github.io")` == `https://w3c-ccg.github.io/.well-known/did.json` |
| W2 | new | `did_web_url("did:web:w3c-ccg.github.io:user:alice")` == `https://w3c-ccg.github.io/user/alice/did.json` |
| W3 | new | `did_web_url("did:web:example.com%3A3000")` == `https://example.com:3000/.well-known/did.json` |
| W4 | new | `did_web_url("did:web:example.com%3A3000:user:alice")` == `https://example.com:3000/user/alice/did.json` |
| W5 | new | `did_web_url(NORTHFIELD)` == `https://guild.northfield.example/chapters/north/did.json` |
| R1, R2, R3 | tightened | was: any `Err`. Now: `Err(UnknownKey \| BadSignature)`, so the retired key must be rejected by the key check against the served document, not by a resolution failure (`rejected_as_retired`) |
| N2, N4, N6 | tightened | same tightening as R1-R3 |
| S1-S4, V1-V7, N1, N3, N5, N7 | unchanged expectation | wrapped in the panic guard. S/V/N documents are now placed at `spec_url(did)` instead of the backend's `did_web_url(did)` |

Without the tightening, R2 and N6 would pass on the cold-run tree only because resolution fails
(`rejected` accepts any error). The tightening makes them red there (C2). It is D14-compliant: no
id was removed, and every old `Ok` outcome is still an `Ok` outcome under the new check.

Case totals: 21 → 26. Pre-plant evidence (test-first): `preplant.txt`. W1-W5 print `ok` on the
unplanted tree, and the unplanted tree + the previous ticket-1.patch gives `axis a: PASS 26/26`.

## Results
| check | file | result |
|---|---|---|
| C1 planted | `planted.txt` | visible suite green (exit 0); `axis a: FAIL 6/26` |
| C2 cold diff | `cold-diff.txt` | the cold diff's verifier.rs hunk no longer applies (its removed comment lines moved in step 3). README + tests hunks applied with `git apply --exclude=backend/src/verifier.rs`; the verifier change was made by hand (the early return deleted, the cold run's doc comment added; `diff -u` recorded). Visible suite green (18 verifier tests, incl. the cold run's 2 new ones); `axis a: FAIL 17/26`; S3, R2, N5, N6 FAIL (Transport NotFound at `.../.well-known/chapters/north/did.json`) |
| C3 repin | `repin.txt` | applies unchanged; suite green; `ok S2`; `axis a: FAIL 8/26` |
| C3 symptom | `symptom.txt` | applies unchanged; suite green; `axis a: FAIL 9/26` |
| C4 ref | `ref.txt` | `git apply --check` clean; numstat: `backend/src/resolver.rs` 10/10, `backend/src/verifier.rs` 5/3 = 28 changed lines; suite green; `axis a: PASS 26/26` |
| C5 composition | `composition.txt` | ticket-1 + ticket-2: `axis a: PASS 26/26`, `axis a2: PASS 17/17`. ticket-2.patch touches only notifier.rs and was not changed |
| C6 feature-ref | `feature-ref.txt` | ticket-1 + overlay: `axis a: PASS 26/26`, `axis b: PASS 7/7` |

## Clone-visible grep for the Northfield path mapping
Clone-visible = `git ls-files --cached --others --exclude-standard` minus `_solutions/`, `README.md`,
`practice.json`, `DESIGN.md`.
```
$ <clone-visible files> | xargs grep -n "chapters/north"     # file contents
(exit=123; no content hits)
$ <clone-visible files> | grep "chapters/north"              # file paths
reference/infra/hosted-dids/guild.northfield.example/chapters/north/did.json
$ <clone-visible files> | xargs grep -n "did\.json"   # every did.json mention outside reference/
backend/src/resolver.rs:78:/// The HTTPS URL a `did:web` document is published at: `did.json` under the
backend/src/resolver.rs:99:    url.push_str("/did.json");
backend/src/transport.rs:3://! Issuer `did.json` documents are published to the document bucket behind
backend/tests/common/mod.rs:117:pub const HARBOUR_URL: &str = "https://members.harbourclub.example/.well-known/did.json";
backend/tests/resolver.rs:93:        "https://members.harbourclub.example/.well-known/did.json"
backend/tests/resolver.rs:99:    assert_eq!(did_web_url("did:web:localhost%3A8443").unwrap(), "https://localhost:8443/.well-known/did.json");
backend/tests/resolver.rs:135:    std::fs::write(dir.join("did.json"), harbour_document().to_string()).unwrap();
backend/tests/resolver.rs:138:    let body = mirror.get("https://members.harbourclub.example/.well-known/did.json").unwrap();
backend/tests/resolver.rs:141:    assert!(mirror.get("http://members.harbourclub.example/.well-known/did.json").is_err());
```
The only statement of the §3.2 path mapping, and the only `chapters/north` hit (the bucket object key),
are under `reference/`. Outside it, every `did.json` URL is a bare-domain `/.well-known/` one or the planted builder.

## `git diff` of the grader
```diff
diff --git a/practices/credentials/_solutions/grader/src/main.rs b/practices/credentials/_solutions/grader/src/main.rs
index f49aa94..25bc4a8 100644
--- a/practices/credentials/_solutions/grader/src/main.rs
+++ b/practices/credentials/_solutions/grader/src/main.rs
@@ -19,12 +19,22 @@
 //! - **N** a grader-only "next rotation": documents newer than anything in
 //!   `reference/`, served only by this grader's transport. Re-pinning an
 //!   onboarding snapshot or hard-coding a key from `reference/` plateaus here.
+//! - **W** URL mapping conformance: the backend's `did_web_url` against the
+//!   §3.2 examples of `reference/did-web-method.md` and the path-based
+//!   Northfield DID (whose object key is in `reference/infra/`).
+//!
+//! The grader never trusts the backend's URL mapping to decide where a
+//! document lives: [`spec_url`] implements §3.2 on its own. A retired key
+//! must be rejected by the key check against the served document, not by a
+//! resolution failure. A case that panics prints as FAIL; every case prints
+//! its own line and the axis line is always last.
 //!
 //! Every scenario builds a fresh `Verifier` over a fresh transport, so the
 //! axis grades where the document comes from, not whether it is cached.
 //! Credentials are signed with the keys in `_solutions/fixtures/issuer-keys.json`.
 
 use std::collections::{BTreeMap, BTreeSet, HashMap};
+use std::panic::{catch_unwind, AssertUnwindSafe};
 use std::path::{Path, PathBuf};
 use std::sync::Arc;
 
@@ -130,8 +140,38 @@ fn document(did: &str, keys: &[&Key], site: &str) -> Value {
     })
 }
 
+/// The document URL of a `did:web` DID, per `reference/did-web-method.md`
+/// §3.2 (steps 1-6). Grader-local: the backend's own mapping is under test.
+fn spec_url(did: &str) -> String {
+    let id = did.strip_prefix("did:web:").unwrap_or_else(|| panic!("not a did:web DID: {did}"));
+    let segments: Vec<String> = id.split(':').map(spec_percent_decode).collect();
+    let (host, path) = segments.split_first().expect("host segment");
+    if path.is_empty() {
+        format!("https://{host}/.well-known/did.json")
+    } else {
+        format!("https://{host}/{}/did.json", path.join("/"))
+    }
+}
+
+fn spec_percent_decode(segment: &str) -> String {
+    let bytes = segment.as_bytes();
+    let mut out = Vec::with_capacity(bytes.len());
+    let mut i = 0;
+    while i < bytes.len() {
+        if bytes[i] == b'%' && i + 3 <= bytes.len() {
+            let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).expect("percent escape");
+            out.push(u8::from_str_radix(hex, 16).expect("percent escape"));
+            i += 3;
+        } else {
+            out.push(bytes[i]);
+            i += 1;
+        }
+    }
+    String::from_utf8(out).expect("utf-8 segment")
+}
+
 fn hosted_document(did: &str) -> Value {
-    let url = did_web_url(did).expect("did:web url");
+    let url = spec_url(did);
     let body = MirrorTransport::new(hosted_root()).get(&url).unwrap_or_else(|e| panic!("hosted {did}: {e}"));
     serde_json::from_slice(&body).expect("hosted document parses")
 }
@@ -152,7 +192,7 @@ impl GraderTransport {
     }
 
     fn serve(mut self, did: &str, document: &Value) -> Self {
-        self.overrides.insert(did_web_url(did).expect("did:web url"), Some(document.to_string().into_bytes()));
+        self.overrides.insert(spec_url(did), Some(document.to_string().into_bytes()));
         self
     }
 
@@ -162,7 +202,7 @@ impl GraderTransport {
     }
 
     fn remove(mut self, did: &str) -> Self {
-        self.overrides.insert(did_web_url(did).expect("did:web url"), None);
+        self.overrides.insert(spec_url(did), None);
         self
     }
 }
@@ -223,6 +263,25 @@ fn rejected(result: Result<VerifiedCredential, VerifyError>) -> Outcome {
     }
 }
 
+/// A retired key: rejected by the key check against the document the issuer
+/// serves (method spec §4), never by a failure to resolve that document.
+fn rejected_as_retired(result: Result<VerifiedCredential, VerifyError>) -> Outcome {
+    match result {
+        Ok(_) => Err("accepted; must be rejected".into()),
+        Err(VerifyError::UnknownKey(_) | VerifyError::BadSignature(_)) => Ok(()),
+        Err(e) => Err(format!("rejected, but not by the key check against the served document: {e} ({e:?})")),
+    }
+}
+
+/// The backend's `did_web_url(did)` must be the §3.2 document URL.
+fn maps_to(did: &str, want: &str) -> Outcome {
+    match did_web_url(did) {
+        Ok(url) if url == want => Ok(()),
+        Ok(url) => Err(format!("did_web_url gives {url}, spec §3.2 gives {want}")),
+        Err(e) => Err(format!("did_web_url failed: {e} ({e:?})")),
+    }
+}
+
 /// Verifies a credential signed with `key` against the served documents.
 fn verify_with(transport: GraderTransport, issuer: &str, key: &Key) -> Result<VerifiedCredential, VerifyError> {
     let (verifier, store) = setup(transport);
@@ -307,36 +366,50 @@ fn main() {
     let hosted = GraderTransport::hosted;
 
     let mut cases: Vec<(&str, String, Outcome)> = Vec::new();
-    let mut case = |id: &'static str, name: &str, outcome: Outcome| cases.push((id, name.to_string(), outcome));
+    // Each case runs under catch_unwind: a panic is that case's FAIL, not the axis's end.
+    std::panic::set_hook(Box::new(|_| {}));
+    let mut case = |id: &'static str, name: &str, run: &dyn Fn() -> Outcome| {
+        let outcome = catch_unwind(AssertUnwindSafe(run)).unwrap_or_else(|panic| {
+            let reason = panic
+                .downcast_ref::<String>()
+                .cloned()
+                .or_else(|| panic.downcast_ref::<&str>().map(|s| s.to_string()))
+                .unwrap_or_else(|| "unknown panic".into());
+            Err(format!("panicked: {reason}"))
+        });
+        cases.push((id, name.to_string(), outcome));
+    };
 
     // S — issuer states as hosted in reference/infra/hosted-dids/.
     case("S1", "never rotated (Harbour Club): current key accepted",
-        accepted(verify_with(hosted(), HARBOUR, &current(HARBOUR)), Some("https://harbourclub.example/")));
+        &|| accepted(verify_with(hosted(), HARBOUR, &current(HARBOUR)), Some("https://harbourclub.example/")));
     case("S2", "rotated key, new id #key-2 (Cedar Rowing): current key accepted",
-        accepted(verify_with(hosted(), CEDAR, &current(CEDAR)), Some("https://cedarrowing.example/")));
+        &|| accepted(verify_with(hosted(), CEDAR, &current(CEDAR)), Some("https://cedarrowing.example/")));
     case("S3", "rotated key, same id #signing, path DID (Northfield): current key accepted",
-        accepted(verify_with(hosted(), NORTHFIELD, &current(NORTHFIELD)), Some("https://guild.northfield.example/")));
+        &|| accepted(verify_with(hosted(), NORTHFIELD, &current(NORTHFIELD)), Some("https://guild.northfield.example/")));
     case("S4", "rotated key + moved endpoint (Kestrel): current key accepted, current issuer site",
-        accepted(verify_with(hosted(), KESTREL, &current(KESTREL)), Some("https://kestrel-league.example/members/")));
+        &|| accepted(verify_with(hosted(), KESTREL, &current(KESTREL)), Some("https://kestrel-league.example/members/")));
 
     // R — keys retired by rotation are no longer keys of the DID (method spec §4).
-    case("R1", "Cedar Rowing: retired #key-1 rejected", rejected(verify_with(hosted(), CEDAR, &onboarded(CEDAR))));
-    case("R2", "Northfield: retired #signing material rejected",
-        rejected(verify_with(hosted(), NORTHFIELD, &onboarded(NORTHFIELD))));
-    case("R3", "Kestrel: retired #key-2025 rejected", rejected(verify_with(hosted(), KESTREL, &onboarded(KESTREL))));
+    case("R1", "Cedar Rowing: retired #key-1 rejected by the key check",
+        &|| rejected_as_retired(verify_with(hosted(), CEDAR, &onboarded(CEDAR))));
+    case("R2", "Northfield: retired #signing material rejected by the key check",
+        &|| rejected_as_retired(verify_with(hosted(), NORTHFIELD, &onboarded(NORTHFIELD))));
+    case("R3", "Kestrel: retired #key-2025 rejected by the key check",
+        &|| rejected_as_retired(verify_with(hosted(), KESTREL, &onboarded(KESTREL))));
 
     // V — conformance vectors derived from reference/.
     for (id, did) in [("V1", HARBOUR), ("V2", CEDAR), ("V3", NORTHFIELD), ("V4", KESTREL)] {
-        case(id, &format!("resolve_issuer({did}) is the hosted did.json (keys + LinkedDomains)"), resolves_to_hosted(did));
+        case(id, &format!("resolve_issuer({did}) is the hosted did.json (keys + LinkedDomains)"), &|| resolves_to_hosted(did));
     }
-    case("V5", "document whose id is not the DID fails resolution (spec §3.2 step 8)", {
+    case("V5", "document whose id is not the DID fails resolution (spec §3.2 step 8)", &|| {
         // Harbour's own key and site, published under another DID's id.
         let foreign = document("did:web:members.harbourclub.example:elsewhere", &[&current(HARBOUR)], "https://harbourclub.example/");
         rejected(verify_with(hosted().serve(HARBOUR, &foreign), HARBOUR, &current(HARBOUR)))
     });
     case("V6", "deactivated issuer (document removed) fails resolution (spec §3.4)",
-        rejected(verify_with(hosted().remove(HARBOUR), HARBOUR, &current(HARBOUR))));
-    case("V7", "ported host did:web:example.com%3A3000:user:alice resolves at host:3000 (spec §3.2)", {
+        &|| rejected(verify_with(hosted().remove(HARBOUR), HARBOUR, &current(HARBOUR))));
+    case("V7", "ported host did:web:example.com%3A3000:user:alice resolves at host:3000 (spec §3.2)", &|| {
         let did = "did:web:example.com%3A3000:user:alice";
         let key = fresh_key(did, "key-1", 0x51);
         let doc = document(did, &[&key], "https://example.com:3000/alice/");
@@ -349,31 +422,47 @@ fn main() {
         let next = fresh_key(HARBOUR, "key-2", 0xA1);
         let doc = document(HARBOUR, &[&next], "https://harbourclub.example/");
         case("N1", "Harbour Club rotates for the first time: new #key-2 accepted",
-            accepted(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &next), None));
-        case("N2", "Harbour Club rotates for the first time: retired #key-1 rejected",
-            rejected(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &current(HARBOUR))));
+            &|| accepted(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &next), None));
+        case("N2", "Harbour Club rotates for the first time: retired #key-1 rejected by the key check",
+            &|| rejected_as_retired(verify_with(hosted().serve(HARBOUR, &doc), HARBOUR, &current(HARBOUR))));
     }
     {
         let next = fresh_key(CEDAR, "key-3", 0xA2);
         let doc = document(CEDAR, &[&next], "https://cedarrowing.example/");
         case("N3", "Cedar Rowing rotates again: new #key-3 accepted",
-            accepted(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &next), None));
-        case("N4", "Cedar Rowing rotates again: #key-2 retired and rejected",
-            rejected(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &current(CEDAR))));
+            &|| accepted(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &next), None));
+        case("N4", "Cedar Rowing rotates again: #key-2 retired and rejected by the key check",
+            &|| rejected_as_retired(verify_with(hosted().serve(CEDAR, &doc), CEDAR, &current(CEDAR))));
     }
     {
         let next = Key { vm: current(NORTHFIELD).vm, seed: [0xA3; 32] };
         let doc = document(NORTHFIELD, &[&next], "https://guild.northfield.example/");
         case("N5", "Northfield rotates #signing again: new material accepted",
-            accepted(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &next), None));
-        case("N6", "Northfield rotates #signing again: previous material rejected",
-            rejected(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &current(NORTHFIELD))));
+            &|| accepted(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &next), None));
+        case("N6", "Northfield rotates #signing again: previous material rejected by the key check",
+            &|| rejected_as_retired(verify_with(hosted().serve(NORTHFIELD, &doc), NORTHFIELD, &current(NORTHFIELD))));
     }
     {
         let next = fresh_key(KESTREL, "key-2027", 0xA4);
         let doc = document(KESTREL, &[&next], "https://kestrel-league.example/clubs/");
         case("N7", "Kestrel rotates key and moves its site again: accepted with the newest site",
-            accepted(verify_with(hosted().serve(KESTREL, &doc), KESTREL, &next), Some("https://kestrel-league.example/clubs/")));
+            &|| accepted(verify_with(hosted().serve(KESTREL, &doc), KESTREL, &next), Some("https://kestrel-league.example/clubs/")));
+    }
+
+    // W — the backend's did_web_url against reference/did-web-method.md §3.2.
+    for (id, did, url) in [
+        ("W1", "did:web:w3c-ccg.github.io", "https://w3c-ccg.github.io/.well-known/did.json"),
+        ("W2", "did:web:w3c-ccg.github.io:user:alice", "https://w3c-ccg.github.io/user/alice/did.json"),
+        ("W3", "did:web:example.com%3A3000", "https://example.com:3000/.well-known/did.json"),
+        ("W4", "did:web:example.com%3A3000:user:alice", "https://example.com:3000/user/alice/did.json"),
+        ("W5", NORTHFIELD, "https://guild.northfield.example/chapters/north/did.json"),
+    ] {
+        case(id, &format!("did_web_url({did}) is {url} (spec §3.2)"), &|| {
+            if spec_url(did) != url {
+                return Err(format!("grader self-check: spec_url gives {}", spec_url(did)));
+            }
+            maps_to(did, url)
+        });
     }
 
     let total = cases.len();
```
