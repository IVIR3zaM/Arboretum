# Trust Registry — service contract

*Snapshot of the Trust Registry service contract. The service is operated by the Governance team
and implements the Trust Registry Query Protocol (TRQP); the implementation is based on
`affinidi-trust-registry-rs`.*

## What it answers

The trust registry is the platform's authority on **which issuers are trusted to issue which
credentials**. An issuer being onboarded, having a resolvable DID, or having signed a credential
correctly does not make it trusted; a registry record does.

Records are keyed on the **entity's DID**. A record authorizes one entity to perform one action on
one resource type under one authority.

| Field | Meaning |
|---|---|
| `entity_id` | the issuer's DID |
| `authority_id` | the governing authority's DID — `did:web:governance.membership-platform.example` |
| `action` | `issue` |
| `resource` | the credential type, e.g. `MembershipCredential` |
| `status` | `active` · `suspended` · `withdrawn` |

## Interface

`POST /authorization`

```json
{
  "entity_id": "did:web:members.harbourclub.example",
  "authority_id": "did:web:governance.membership-platform.example",
  "action": "issue",
  "resource": "MembershipCredential"
}
```

Response `200 OK`:

```json
{
  "entity_id": "did:web:members.harbourclub.example",
  "authority_id": "did:web:governance.membership-platform.example",
  "action": "issue",
  "resource": "MembershipCredential",
  "authorized": true,
  "time_evaluated": "2026-09-01T09:14:03Z"
}
```

`authorized` is `true` only for a record whose `status` is `active`. An unknown `entity_id`
returns `200 OK` with `authorized: false`; it is not an error.

`POST /recognition` answers the same question for authorities (`action`: `recognize`) and is not
used by relying parties.

## The invariant consumers depend on

**Trust is decided by the registry at the time of verification.** A relying party verifying a
credential MUST query the registry for the credential's `issuer` DID, action `issue` and the
credential's type, and MUST refuse the credential unless `authorized` is `true`. Consumers MUST
NOT keep their own list of trusted issuers: records are suspended and withdrawn without notice
to relying parties, and a registry answer may be cached for at most 300 seconds.

Changes to an issuer's DID document — rotated keys, moved service endpoints — do not change its
registry record. The record follows the DID.

## Current records (export, 2026-09-01)

| entity_id | action | resource | status | since |
|---|---|---|---|---|
| `did:web:members.harbourclub.example` | issue | MembershipCredential | active | 2025-03-14 |
| `did:web:issuer.cedarrowing.example` | issue | MembershipCredential | active | 2025-05-02 |
| `did:web:guild.northfield.example:chapters:north` | issue | MembershipCredential | active | 2025-06-20 |
| `did:web:badges.kestrel-league.example` | issue | MembershipCredential | active | 2025-09-08 |
