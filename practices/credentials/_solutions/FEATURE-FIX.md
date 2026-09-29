# FEATURE-FIX — `WalletService.createPresentation` (phase 3)

The reference elicited build of the phase-3 feature, what it does, and what it defers — out loud.

## Minimal correct behaviour

`createPresentation(credentialId, request)` returns a Verifiable Presentation (a JSON map) that:

1. **Discloses exactly the requested subset.** The request's DCQL query (`request.dcqlQuery`) is
   evaluated with the pinned Affinidi `dcql` package against a W3C view of the held credential; only
   the disclosures for the claims the matched credential query names (its `claims`, or the first
   satisfied `claim_sets` option) are included, each exactly as issued (`{salt, name, value}`). A query
   with no `claims` discloses nothing. The issuer-signed credential travels unchanged (a deep copy).
2. **Is signed by the holder's key.** `Ed25519Signature2020`, `proofPurpose: authentication`,
   `verificationMethod` = `HolderKey.keyId` (`<did:key>#<multibase>`), `proofValue` = multibase
   base58btc of the Ed25519 signature over the RFC 8785 (JCS) bytes of the presentation minus `proof`
   (`JcsUtil.canonicalize` from `ssi`). `holder` is the wallet's did:key, which must be the credential's
   `credentialSubject.id`.
3. **Is bound to the request's nonce and domain.** `nonce` = `request.nonce`, `domain` =
   `request.domain` (the requester's `client_id`), both under the holder proof — so a captured
   presentation is rejected by any other scanner or request.
4. **Refuses an expired credential.** If `now >= expires_at` (integer unix seconds; a W3C
   `validUntil` / `expirationDate` is honoured too) it throws a `WalletException` and builds nothing.
   An unknown credential id, or a credential not bound to this wallet's holder key, is refused the same
   way.

Wire shape (the backend's contract):

```json
{
  "@context": ["https://www.w3.org/2018/credentials/v1"],
  "type": ["VerifiablePresentation"],
  "holder": "did:key:z6Mk...",
  "verifiableCredential": { "...the VC as issued, with its proof..." },
  "disclosures": [ { "salt": "...", "name": "member", "value": true } ],
  "nonce": "<request.nonce>",
  "domain": "<request.client_id>",
  "proof": { "type": "Ed25519Signature2020", "created": 1780272000,
             "verificationMethod": "did:key:z6Mk...#z6Mk...",
             "proofPurpose": "authentication", "proofValue": "z..." }
}
```

## Deferred — out loud

- Sending the presentation to the scanner (`response_uri`) and any door UI / QR flow.
- Choosing among several matching credentials, and DCQL `credential_sets` spanning credentials;
  claim paths deeper than `credentialSubject.<name>` are refused, not guessed.
- A wallet-side not-yet-valid (`not_before`) check.
- Holder-side revocation / status checks — the verifier's job.
- Enforced single-use: v1 has none (the backend README's "single-use" is not implemented); the nonce
  stops replay of the *same* presentation, and the credential may be presented again to a new request.
- Holder key rotation, and the planted latent defects (none is needed for this feature).

## The reference build

`_solutions/feature-reference/` is an overlay mirroring practice-relative paths:

| File | Change |
|---|---|
| `app/lib/src/wallet_service.dart` | the planted file with `createPresentation` implemented (expiry check, holder binding check, VP build, holder proof) |
| `app/lib/src/dcql_selection.dart` | new: `selectDisclosures(held, query)` — DCQL evaluation via `dcql` and the claim-to-disclosure mapping |

Apply it to a copy of the planted tree and grade:

```
cp -R _solutions/feature-reference/. .
bash _solutions/grade.d/b.sh        # → axis b: PASS 7/7
```

It needs no Ticket-1 fix, no Ticket-2 fix and no latent fix. The visible app suite stays green and
`flutter analyze` is clean with the overlay applied.

## The gate (axis b) and why a raw build fails it

`grade.d/b.sh` scores seven cases: four wallet `feature:` cases (the hidden Dart file
`_solutions/app-tests/feature_gate_test.dart`, run headless with `flutter test --no-pub` in a temp copy
of `app/`) and three `xstack:` cases (the hidden Rust bin `_solutions/xstack/`, which issues the gate's
credentials with the backend's own `Issuer` from the never-rotated Harbour Club did:web and feeds the
wallet's presentation to the backend's `Verifier::verify_presentation`).

| Case | What a raw "package it up" build does |
|---|---|
| feature: discloses exactly the claims the DCQL query asks for | discloses every claim (birth date included) — FAIL |
| feature: the presentation is signed by the holder's key | often missing ("already issuer-signed") — FAIL; passes if the build does sign |
| feature: the presentation is bound to the request's nonce and domain | no nonce/domain — FAIL |
| feature: an expired credential is refused | presents it anyway — FAIL |
| xstack: the backend verifier accepts the wallet's presentation | verifier rejects it (no nonce) — FAIL |
| xstack: the backend verifier rejects a tampered disclosed value | precondition (the untouched presentation is accepted) fails — FAIL |
| xstack: the backend verifier rejects the presentation replayed to another nonce or domain | precondition fails — FAIL |

The two rejection cases count only when the untouched presentation is accepted first, so a build is
never credited for being rejected for the wrong reason. The cross-stack accept case also checks the
holder proof strictly (type, key id, signature) itself, rather than relying on the verifier's
proof-type handling. A self-check wrap-all build that *is* holder-signed but ignores the query, the
nonce and the domain scores `axis b: FAIL 1/7`.
