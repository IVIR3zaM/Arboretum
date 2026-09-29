# context-map — the golden cross-boundary contract

> Spoiler / answer key. Examiner-only; stripped from the learner clone. This is what
> `research-notes.md` (written by the learner inside `work/`, AGENTS.md rule 9) should converge on
> after reading `reference/` — the examiner's copy of the ground truth to grade that research pass
> against.

## The one load-bearing fact

**A `did:web` DID document is whatever the issuer's domain serves now.** It is not in the
identifier, it is not self-certifying, and it changes when the issuer rotates a key or moves an
endpoint (`reference/did-web-method.md` §3.3, §4, §5 "Key rotation", "No self-certification").
A verifier must resolve it when it verifies, and a key that is no longer in the served document is
not a key of the DID. Everything Ticket 1 needs follows from this; a fix, a review or a research
note that treats the onboarding copy in `backend/data/onboarded-issuers.json` as the issuer's keys
is wrong however it is reached.

Ticket 2's load-bearing fact is the same shape, on the infrastructure side: **the notifier is killed
at 10 s, is never retried, and nobody is alarmed when that happens**
(`reference/infra/webhook-config.yaml`) — so anything a change's fan-out has not delivered by then
is lost silently, and the only health signal is the canary.

## Current method: did:web, resolved by a live fetch

The repo's history moved `did:key` → `did:peer:2` → **`did:web`** (current, authoritative), so
issuers could rotate keys without re-issuing credentials. All four onboarded issuers are `did:web`.
The backend README still describes the first era (`did:key`, "no lookup, no network"); the
`Store::onboarded_issuer` comment describes the second ("self-contained, as with the peer DIDs").
Neither is current (see `doc-drift-ledger.md`). Holders are still `did:key` — that part is current.

**Resolution** (`did-web-method.md` §3.2): strip `did:web:`, split on `:`, percent-decode each
segment (a port is `%3A`), and:

| DID | Document URL |
|---|---|
| `did:web:<host>` | `https://<host>/.well-known/did.json` |
| `did:web:<host>:<p1>:<p2>` | `https://<host>/<p1>/<p2>/did.json` — **no** `/.well-known` |

The document's `id` must equal the DID; a removed document means the DID is deactivated (§3.4).
HTTPS only. `reference/infra/did-hosting.md` confirms the same layout as object keys in the
platform's document bucket (`<host>/.well-known/did.json` for a bare domain,
`<host>/<p1>/<p2>/did.json` for a path DID), served with `Cache-Control: max-age=300`; the previous
version stays in bucket history but "is no longer served".

## Where the hosted-document truth lives

Only in `reference/infra/hosted-dids/`, one file per object key. The local repo never has the
rotated keys.

| Issuer DID | State since onboarding | Hosted object |
|---|---|---|
| `did:web:members.harbourclub.example` | never rotated (snapshot == hosted) | `members.harbourclub.example/.well-known/did.json` |
| `did:web:issuer.cedarrowing.example` | rotated key, new id `#key-1` → `#key-2` | `issuer.cedarrowing.example/.well-known/did.json` |
| `did:web:guild.northfield.example:chapters:north` | rotated key material, **same** id `#signing`; a path DID | `guild.northfield.example/chapters/north/did.json` |
| `did:web:badges.kestrel-league.example` | rotated key `#key-2025` → `#key-2026` **and** LinkedDomains endpoint moved (`https://badges.kestrel-league.example/` → `https://kestrel-league.example/members/`) | `badges.kestrel-league.example/.well-known/did.json` |

The Northfield object key is the only place (outside `did-web-method.md`'s own examples) that shows
a path DID's document is not under `/.well-known`.

## Trust: the registry, keyed on the DID, checked live

`reference/trust-registry.md`: a relying party verifying a credential **must** query the registry
(`POST /authorization`, the credential's `issuer`, action `issue`, the credential type) and refuse
unless `authorized` is `true`; it must not keep its own list; an answer may be cached for at most
300 s. Rotations do not change the registry record — "the record follows the DID". All four
onboarded issuers are `active`. The backend has no registry client at all (latent #6); the fix to
Ticket 1 does not need one, and none of the graded issuers is refused by the registry.

## The webhook infrastructure facts (Ticket 2)

All in `reference/infra/webhook-config.yaml` (the `status-notifier` deployment) and
`reference/infra/reserved-domains.md`; none is visible from `backend/` alone.

| Fact | Source | Why it matters |
|---|---|---|
| **Dispatch budget: 10 s, a hard kill.** "The runtime terminates the invocation when it is reached; work still in progress at that point is abandoned." | `function.timeout_seconds: 10` | a fan-out that has not finished by 10 s delivers nothing more; raising the local `DISPATCH_BUDGET` constant changes nothing in production |
| **No retry, no failure destination.** | `async_invocation.maximum_retry_attempts: 0`, `on_failure_destination: none` | a call that is not made (or fails) is never made again; the README's "failed deliveries retried" is false |
| **No alarm.** | `monitoring.alarms: []` | a timed-out fan-out alerts nobody; the log line is the only trace — the observability gap A1 names |
| **The tenant-kind index exists.** | `tables.tenant-settings.global_secondary_indexes: tenant-kind-index`, `query_page_size: 100` | a tenant's webhook subscriptions can be read by kind; scanning every setting is the A3 defect (the local `SettingsStore::query_kind` is its analogue) |
| **Reserved names are never live endpoints.** `example.com`, `example.net`, `example.org` (RFC 2606 §3) must not appear as a live endpoint in any production code path — "webhooks and callbacks, health and liveness probes, synthetic monitoring". A probe target must be "an endpoint the platform operates, reached over the same path as the traffic it vouches for". | `reserved-domains.md` | the canary targets `example.com` and runs before the real path: a green canary says nothing about customers (A4) |

## What a research pass should come away with

A `research-notes.md` that reconciles the local repo against this map should state, in the learner's
own words, at minimum:

- the issuers are on **did:web**; resolving one is a **live HTTPS fetch** of the document the domain
  serves now; documents **rotate**, and a retired key is not a key of the DID;
- a **path DID** maps to `https://<host>/<path>/did.json`, not under `/.well-known`;
- the local onboarding copy is a **stale snapshot**, the READMEs/comments describing `did:key` or
  "self-contained peer DIDs" are **out of date**, and which local code path still trusts the
  snapshot (`Verifier::resolve_issuer`);
- trust is a **registry** question keyed on the DID, checked at verification time (and the backend
  does not ask);
- for Ticket 2 (once staged): the **10 s hard kill**, **no retries**, **no alarm**, the
  **tenant-kind index**, and the **reserved-domain rule** — and that the canary, as built, vouches
  for nothing a customer depends on.

Credit a note that connects each external fact to the specific local place that violates it. A note
that restates the ticket, or that lists `reference/` files without saying what they contradict, is
not a research pass.
