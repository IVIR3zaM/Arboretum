# credentials-backend — issuer & verifier service

The service side of the membership system. It signs membership credentials for the clubs and
leagues we've onboarded, and checks the presentations members show at the door.

## How it works

**Issuers.** We identify issuers with `did:key`: an issuer's DID *is* its Ed25519 public key, so
checking an issuer's signature needs nothing but the DID in the credential — no registry lookup,
no network call. An issuer is approved once, at onboarding, and is recorded in
`data/onboarded-issuers.json`.

**Credentials.** A credential is a JSON-LD verifiable credential signed by its issuer
(`Ed25519Signature2020`, over the RFC 8785 canonical form of the credential without its `proof`).
It carries:

| Field | Meaning |
|---|---|
| `issuer` | the issuer's DID |
| `credentialSubject.id` | the member's (holder's) `did:key` |
| `credentialSubject._sd` | salted SHA-256 digests of the claims — never the claims themselves |
| `issued_at`, `not_before` | unix seconds |
| `expirationDate` | unix seconds; the credential is refused after it |
| `credentialStatus` | the issuer's status list and this credential's index in it |
| `proof` | the issuer's signature |

The member receives the credential together with one *disclosure* (`salt`, `name`, `value`) per
claim, and reveals only the claims a door asks for.

**Presentations.** At the door the member's wallet wraps the credential and the chosen disclosures
in a presentation bound to the scanner's `nonce` and `domain`, and signs it with the member's key.
Credentials are single-use: once a credential has been presented at a door it cannot be presented
again.

**Revocation.** Each issuer has a status list — a bitstring with one bit per credential it has
issued. Revoking a credential sets its bit; the verifier refuses any credential whose bit is set.

## Layout

| File | What it does |
|---|---|
| `src/issuer.rs` | onboarding issuers; `Issuer::issue` signs a credential and its disclosures |
| `src/verifier.rs` | `Verifier::verify_presentation` / `verify_credential` |
| `src/resolver.rs` | `Resolver` — DID to DID document |
| `src/transport.rs` | fetching hosted documents (`MirrorTransport`, `StaticTransport`) |
| `src/credential.rs` | wire format: canonical JSON, proofs, disclosures |
| `src/status.rs` | status lists and `revoke_credential` |
| `src/store.rs` | in-memory store: onboarded issuers, issued credentials, status lists |
| `data/onboarded-issuers.json` | the issuers approved to issue through the service |

## Tests

```
cargo test
```

The suite runs offline against fixture keys and documents.
