//! Axis (b), cross-stack half: the backend's own verifier judges the wallet's presentation.
//!
//! `xstack issue <gate-dir>`
//!     Issues two membership credentials from Harbour Club (the never-rotated did:web issuer) to the
//!     gate's holder (did:key of seed [7; 32]) and writes them as issuance responses:
//!     `issued-valid.json` (valid now, for a year) and `issued-expired.json` (expired a day ago).
//!
//! `xstack verify <gate-dir> <hosted-dids-root>`
//!     Reads `<gate-dir>/out/vp.json` (`{"nonce", "domain", "presentation"}`, written by the Dart gate
//!     from `WalletService.createPresentation`) and runs the three cross-stack cases through
//!     `Verifier::verify_presentation`, printing one `case <name>: PASS|FAIL — <why>` line each.
//!
//! No case depends on Ticket 1, Ticket 2 or a latent defect being fixed: Harbour's hosted document equals
//! its onboarding snapshot, every submission gets a fresh request id (latent #1), no case sits on the
//! expiry instant (latent #4), and the holder proof is checked strictly here rather than trusting the
//! verifier's proof-type fall-through (latent #7).

use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use credentials_backend::credential::{self, ED25519_SIGNATURE_2020};
use credentials_backend::issuer::{CredentialRequest, IssuedCredential, Issuer};
use credentials_backend::resolver::{did_key_for, Resolver};
use credentials_backend::store::Store;
use credentials_backend::transport::MirrorTransport;
use credentials_backend::verifier::{Submission, Verifier, VerifyError};
use ed25519_dalek::SigningKey;
use serde_json::{json, Value};

const HARBOUR_DID: &str = "did:web:members.harbourclub.example";
const HARBOUR_KEY_ID: &str = "did:web:members.harbourclub.example#key-1";
const HARBOUR_SEED: &str = "9f3688f6e8b93b0cfa3b11c28fbc25fe5440192ed82835e7fe3ab590f03f6c75";
const HOLDER_SEED_BYTE: u8 = 7;
const DAY: i64 = 86_400;

const CASE_ACCEPT: &str = "xstack: the backend verifier accepts the wallet's presentation";
const CASE_TAMPER: &str = "xstack: the backend verifier rejects a tampered disclosed value";
const CASE_REPLAY: &str = "xstack: the backend verifier rejects the presentation replayed to another nonce or domain";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("issue") if args.len() == 3 => match issue(Path::new(&args[2])) {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => {
                eprintln!("xstack issue: {e}");
                ExitCode::FAILURE
            }
        },
        Some("verify") if args.len() == 4 => {
            verify(Path::new(&args[2]), Path::new(&args[3]));
            ExitCode::SUCCESS
        }
        _ => {
            eprintln!("usage: xstack issue <gate-dir> | xstack verify <gate-dir> <hosted-dids-root>");
            ExitCode::from(2)
        }
    }
}

fn now() -> i64 {
    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or_default()
}

fn seed(hex: &str) -> [u8; 32] {
    let mut out = [0u8; 32];
    for (i, byte) in out.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&hex[2 * i..2 * i + 2], 16).expect("hex seed");
    }
    out
}

fn holder_key() -> SigningKey {
    SigningKey::from_bytes(&[HOLDER_SEED_BYTE; 32])
}

fn holder_did() -> String {
    did_key_for(&holder_key().verifying_key())
}

fn issue(gate: &Path) -> Result<(), String> {
    std::fs::create_dir_all(gate).map_err(|e| e.to_string())?;
    let store = Store::new();
    let harbour = Issuer::new(HARBOUR_DID, HARBOUR_KEY_ID, &seed(HARBOUR_SEED));
    let t = now();
    let claims = || {
        vec![
            ("member".to_string(), json!(true)),
            ("memberId".to_string(), json!("M-20417")),
            ("name".to_string(), json!("Ada Park")),
            ("birthDate".to_string(), json!("1990-04-12")),
        ]
    };
    let request = |issued_at: i64, expires_at: i64| CredentialRequest {
        holder: holder_did(),
        credential_type: "MembershipCredential".into(),
        claims: claims(),
        issued_at,
        not_before: None,
        expires_at,
    };
    let valid = harbour.issue(&store, &request(t - DAY, t + 365 * DAY)).map_err(|e| e.to_string())?;
    let expired = harbour.issue(&store, &request(t - 400 * DAY, t - DAY)).map_err(|e| e.to_string())?;
    write(&gate.join("issued-valid.json"), &issuance(&valid))?;
    write(&gate.join("issued-expired.json"), &issuance(&expired))?;
    write(&gate.join("holder.json"), &json!({ "did": holder_did() }))?;
    Ok(())
}

fn issuance(issued: &IssuedCredential) -> Value {
    json!({ "credential": issued.credential, "disclosures": issued.disclosures })
}

fn write(path: &Path, value: &Value) -> Result<(), String> {
    let body = serde_json::to_string_pretty(value).map_err(|e| e.to_string())?;
    std::fs::write(path, body).map_err(|e| format!("{}: {e}", path.display()))
}

fn report(name: &str, outcome: Result<(), String>) {
    match outcome {
        Ok(()) => println!("case {name}: PASS"),
        Err(why) => println!("case {name}: FAIL — {why}"),
    }
}

struct Gate {
    verifier: Verifier,
    requests: AtomicUsize,
}

impl Gate {
    fn new(hosted: &Path) -> Self {
        let store = Arc::new(Store::from_onboarding_data().expect("onboarding data parses"));
        // Status lists live in memory: re-open Harbour's list so its (never revoked) entries resolve.
        store.allocate_status_index(&format!("{HARBOUR_DID}#revocation"));
        let resolver = Resolver::new(Arc::new(MirrorTransport::new(hosted)));
        Gate { verifier: Verifier::new(resolver, store), requests: AtomicUsize::new(0) }
    }

    /// Every submission is a fresh upload: its own request id, so the request-id guard never fires.
    fn submit(&self, presentation: &Value, nonce: &str, domain: &str) -> Result<(), VerifyError> {
        let n = self.requests.fetch_add(1, Ordering::SeqCst);
        let submission = Submission { request_id: format!("xstack-{n}"), presentation: presentation.clone() };
        self.verifier.verify_presentation(&submission, nonce, domain).map(|_| ())
    }

    /// The valid presentation must be accepted — the precondition for the two rejection cases, which
    /// only mean something if the untouched presentation passes.
    fn accepts(&self, vp: &Value, nonce: &str, domain: &str) -> Result<(), String> {
        let holder = holder_did();
        if vp.get("holder").and_then(Value::as_str) != Some(holder.as_str()) {
            return Err(format!("holder is {:?}, expected the wallet's did:key {holder}", vp.get("holder")));
        }
        let proof = vp.get("proof").ok_or("presentation has no proof")?;
        if proof.get("type").and_then(Value::as_str) != Some(ED25519_SIGNATURE_2020) {
            return Err(format!("proof.type is {:?}, expected {ED25519_SIGNATURE_2020}", proof.get("type")));
        }
        let key_id = format!("{holder}#{}", holder.trim_start_matches("did:key:"));
        if proof.get("verificationMethod").and_then(Value::as_str) != Some(key_id.as_str()) {
            return Err(format!("proof.verificationMethod is {:?}, expected {key_id}", proof.get("verificationMethod")));
        }
        credential::verify_signature(vp, &holder_key().verifying_key()).map_err(|e| format!("holder proof: {e}"))?;
        self.submit(vp, nonce, domain).map_err(|e| format!("verifier rejected it: {e} ({e:?})"))
    }
}

fn tamper(vp: &Value) -> Option<Value> {
    let mut tampered = vp.clone();
    let disclosure = tampered.get_mut("disclosures")?.as_array_mut()?.first_mut()?;
    let value = disclosure.get_mut("value")?;
    *value = match value {
        Value::Bool(b) => Value::Bool(!*b),
        Value::String(s) => Value::String(format!("{s}-tampered")),
        Value::Number(n) => json!(n.as_i64().unwrap_or_default() + 1),
        _ => json!("tampered"),
    };
    Some(tampered)
}

fn verify(gate: &Path, hosted: &Path) {
    let path: PathBuf = gate.join("out").join("vp.json");
    let loaded: Result<(Value, String, String), String> = std::fs::read_to_string(&path)
        .map_err(|e| format!("no presentation from the wallet ({}: {e})", path.display()))
        .and_then(|body| serde_json::from_str::<Value>(&body).map_err(|e| format!("vp.json: {e}")))
        .and_then(|doc| {
            let nonce = doc.get("nonce").and_then(Value::as_str).ok_or("vp.json has no nonce")?.to_string();
            let domain = doc.get("domain").and_then(Value::as_str).ok_or("vp.json has no domain")?.to_string();
            let vp = doc.get("presentation").cloned().ok_or("vp.json has no presentation")?;
            Ok((vp, nonce, domain))
        });
    let (vp, nonce, domain) = match loaded {
        Ok(loaded) => loaded,
        Err(why) => {
            for case in [CASE_ACCEPT, CASE_TAMPER, CASE_REPLAY] {
                report(case, Err(why.clone()));
            }
            return;
        }
    };
    let gate = Gate::new(hosted);

    let accepted = gate.accepts(&vp, &nonce, &domain);
    report(CASE_ACCEPT, accepted.clone());
    let precondition = |then: &dyn Fn() -> Result<(), String>| match &accepted {
        Ok(()) => then(),
        Err(why) => Err(format!("the untouched presentation is not accepted ({why})")),
    };

    report(
        CASE_TAMPER,
        precondition(&|| {
            let tampered = tamper(&vp).ok_or("presentation discloses nothing to tamper with")?;
            match gate.submit(&tampered, &nonce, &domain) {
                Ok(()) => Err("a presentation with an edited disclosure value was accepted".into()),
                Err(_) => Ok(()),
            }
        }),
    );

    report(
        CASE_REPLAY,
        precondition(&|| {
            match gate.submit(&vp, &format!("{nonce}-other"), &domain) {
                Err(VerifyError::NonceMismatch) => {}
                Ok(()) => return Err("accepted against another scanner's nonce".into()),
                Err(e) => return Err(format!("another nonce: expected NonceMismatch, got {e:?}")),
            }
            match gate.submit(&vp, &nonce, &format!("other.{domain}")) {
                Err(VerifyError::DomainMismatch) => Ok(()),
                Ok(()) => Err("accepted against another domain".into()),
                Err(e) => Err(format!("another domain: expected DomainMismatch, got {e:?}")),
            }
        }),
    );
}
