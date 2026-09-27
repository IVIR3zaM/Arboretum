# doc-drift-ledger — every planted contradiction, and why

> Spoiler / answer key. Examiner-only; stripped from the learner clone. Each row: what a learner or
> assistant meets locally, its authoritative source, and why the local text is wrong. This is the
> reconcile-docs (FM-15) answer key. Every drifting line is written as belief — stated as fact by
> someone who once believed it, never hedged.

**In one sentence:** the backend README says issuers are `did:key`; the code mostly does `did:web`;
and one stale path — `Verifier::resolve_issuer`'s onboarding-snapshot early return — still assumes
issuer documents are static and self-certifying, with no doc trace of its own.

| Where the drift lives | What it claims | Authoritative source | Why it's wrong / what to trust instead |
|---|---|---|---|
| `backend/README.md:8-10` — "We identify issuers with `did:key`: an issuer's DID *is* its Ed25519 public key, so checking an issuer's signature needs nothing but the DID in the credential — no registry lookup, no network call." | Issuers are `did:key`; verification is offline and registry-free. | `backend/data/onboarded-issuers.json` (all four issuers are `did:web`), `backend/src/resolver.rs` (`resolve_web`), `reference/did-web-method.md`, `reference/trust-registry.md`. | **Two migrations stale** (`did:key` → `did:peer:2` → `did:web`). A did:web document must be fetched, and it rotates; the registry must be asked. A prompt that trusts this line hunts for a did:key decode path and never reaches the resolver. The headline FM-15 trap. |
| `backend/src/store.rs:68-70` — the `Store::onboarded_issuer` doc comment: "Issuer documents are self-contained, as with the peer DIDs issuers first onboarded with: keys and service endpoints travel with the document, so the copy recorded at onboarding is all verification needs." | The onboarding copy is enough to verify against. | `reference/did-web-method.md` §3.3, §4 and §5 ("No self-certification"; "only the current document is authoritative"). | The `did:peer:2` era's assumption, true then and silently false for `did:web`. It sits on the accessor the stale path calls, not on the stale path, so reading `resolve_issuer` alone shows ordinary resolver code. Moved here from the verifier during the build; the comment is unchanged. |
| `backend/src/verifier.rs:196-202` — `resolve_issuer` returns `store.onboarded_issuer(did)`'s document for any onboarded issuer. **No doc or comment admits it.** | (Code, not prose.) Its one-line doc — "The DID document an issuer's credentials are checked against." — reads as correct. | `reference/did-web-method.md` §4; the hosted documents in `reference/infra/hosted-dids/`. | The **stale no-doc-trace path**. It survives because the visible suite verifies only the never-rotated Harbour Club, for which snapshot == hosted. The Ticket 1 root. |
| `backend/src/resolver.rs:78-81` — `did_web_url`'s doc comment: "`did.json` under the host's `/.well-known/` directory, with any further segments of the identifier as subdirectories." | Path DIDs map under `/.well-known`. | `reference/did-web-method.md` §3.2 (only a bare domain gets `/.well-known`) and `reference/infra/did-hosting.md`'s object-key table. | Describes the planted mapping as intended. The only statement of the correct path mapping, and the only `chapters/north` object key, are under `reference/`. |
| `backend/README.md:23` — the credential field table lists `expirationDate`: "unix seconds; the credential is refused after it". | The expiry field is `expirationDate`. | `backend/src/issuer.rs:132` and `backend/src/verifier.rs:165` (`expires_at`); `feature-qa.md` Q4. | The field was renamed; the table was not. A wallet built from the README reads a field the issuer never writes and presents expired credentials. |
| `backend/README.md:32-33` — "Credentials are single-use: once a credential has been presented at a door it cannot be presented again." | Single use is enforced. | The code: only a replay guard on the transport `request_id` (`verifier.rs:111`) exists; nothing tracks presented credentials. `feature-qa.md` Q6 (the Verifier team, confirmed by the PM): not in v1, and not the design. | A claim with no code behind it, and the feature's held-back requirement: a wallet that "consumes" the credential after presenting it locks members out after their first visit. Resolve it out loud. |
| `backend/README.md:38-42` — "Status notifications are delivered concurrently to every subscriber, with failed deliveries retried." | The fan-out is concurrent and fault-isolated, with retries. | `backend/src/notifier.rs:141-149` (a sequential loop, no retry) and `reference/infra/webhook-config.yaml` (`maximum_retry_attempts: 0`). | Written by someone who believed it. It tells a reader the fan-out is already fault-isolated, which hides A2 (head-of-line) and the no-retry fact. The same paragraph's "the notifier reports healthy while the canary is acknowledging them" is accurate about the code, and that is the problem (A4). |
| `app/README.md:8-10` — "Credentials are **JWT-VCs**: the issuer signs a compact JWT whose `vc` claim carries the credential, and the wallet keeps that token exactly as issued." | The wallet holds JWT-VCs. | `app/lib/src/held_credential.dart` (a JSON-LD VC map with a Data Integrity `proof`), the backend's issuer (`Ed25519Signature2020` over JCS), the request fixture's `format: ldp_vc`. | A presentation built from this line would wrap a JWT the verifier cannot read. The holder `did:key` sentence that follows is current. |

## How to use this table

A learner's `research-notes.md` need not reproduce the table, but a research pass that never notices
*any* of these — above all the `did:key` line — and instead builds toward what a stale line
describes is a clear FM-15 miss (`rubric.md`). The tell in a transcript is a prompt or summary that
repeats a left-hand claim as current fact. Credit a run that fixes a drifting line it touched (the
recorded runs corrected the "peer DIDs" comment — the Ticket 1 cold run; `expirationDate`, the
single-use paragraph and the JWT line — the elicited feature run; and the retry claim — the Ticket 2
cold run), and one that names a line and leaves it
for the owner. Neither needs to rewrite every README.

## Drift found by runs but not planted

`app/test/fixtures.dart` builds its credential in a different shape from what the backend issues:
a VC Data Model 2.0 context, `validFrom`/`validUntil` ISO dates and a `DataIntegrityProof`
(`eddsa-jcs-2022`) with a placeholder signature, where the backend writes the v1 context,
`expires_at` integer seconds and `Ed25519Signature2020`. The elicited feature run noticed and
replaced it with a backend-issued credential. It is real fixture drift, but it was not planted and is
not in any count (see `trap-manifest.md`, emergent findings).
