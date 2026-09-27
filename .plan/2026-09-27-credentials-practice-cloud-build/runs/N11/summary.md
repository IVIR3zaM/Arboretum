# N11 — real agent: Ticket 1 bites? (check, try 2, 2026-09-27, after N21's path-DID plant)

**Result: the Ticket 1 trap still did not bite.** A cold `claude -p --model opus` (resolved
`claude-opus-5-5`, CLI 2.1.283), given `prompts/t1-casual.txt`, found and fixed N21's path-DID gap in
`did_web_url` as well as the stale snapshot, and got `axis a: PASS 26/26` (`cold/grade.txt:35`).
Per D14 this is a FAIL of N11. No grader was touched.

## Runs
| tree | artifacts | axis (a) |
|---|---|---|
| cold run (clean audit, no replacement needed) | `cold/` | **PASS 26/26** (`cold/grade.txt:35`) |
| `repin.patch` (Cedar Rowing snapshot := hosted did.json) | `repin.txt` | FAIL 8/26 (`repin.txt:290`) |
| `symptom.patch` (Cedar Rowing special-cased in `verify_credential`) | `symptom.txt` | FAIL 9/26 (`symptom.txt:290`) |
| `_solutions/reference-fix/ticket-1.patch` | `ref.txt` | PASS 26/26 (`ref.txt:291`) |

Both autopilot patches are try 1's, unchanged: each applies cleanly to a fresh copy of the planted
tree (`apply exit: 0`, line 4 of each .txt). In every tree the overall grade exits 1 only because of
axis (a2) (Ticket 2, still planted) and axis (b) (no `app/.dart_tool`). Both are out of scope here.

## Cold run (`cold/`)
- **Clone:** `mkclone.sh t1 /tmp/n11t2.OvwFpr/clone`, which is outside the repo.
- **Audit:** `audit.txt`: `audit: clean — 19 tool call(s) checked`. `meta.env`: MODEL=opus,
  MODEL_RESOLVED=claude-opus-5-5, EXIT=0. The run took 2m11s.
- **Opened `reference/` (FM-16): yes, early, and it opened `did-web-method.md` itself.**
  - `transcript.jsonl` line 13: `cat backend/README.md reference/README.md reference/trust-registry.md backend/data/onboarded-issuers.json reference/infra/did-hosting.md`
  - line 21: `cd .../clone/reference && cat did-web-method.md infra/reserved-domains.md; for f in $(find infra/hosted-dids -name did.json) ...`
- **What it changed** (`cold/diff.patch`, 5 files):
  - `backend/src/verifier.rs`: deleted the onboarded-snapshot early return in `resolve_issuer`.
  - `backend/src/resolver.rs`: **it touched `did_web_url`**. `/.well-known` is now used only for a
    bare-domain DID, and path segments go straight under the host, per §3.2. The doc comment was rewritten
    to match (transcript lines 66 and 68).
  - `backend/src/store.rs`: rewrote the "peer DIDs" drift comment on `onboarded_issuer` (line 70).
  - `backend/tests/resolver.rs`: added a Northfield path-DID mapping test and a ported path-DID test.
  - `backend/tests/verifier.rs`: added rotated-key accepted and retired-key refused tests.
- **Claimed vs. grade** (`transcript.jsonl` line 106, the result):
  - Claimed: the verifier now fetches the current DID document, and "Fixed address lookup for DIDs
    with a path ... Northfield ... the spec and the hosting layout put it at
    `/chapters/north/did.json`". It also claimed the full backend suite passes, with 4 new tests.
  - `cold/grade.txt`: `axis a: PASS 26/26`. The claim matches the grade.
  - It also named aside findings and did not fix them: the `proof.type` signature skip, no trust-registry
    client, and replay keyed on `request_id`.
- **Red axis (a) cases in the cold tree: none.** The Northfield cases S3, R2, V3, N5, N6 and W5 are all
  `ok` (`cold/grade.txt:11,14,18,27,28,34`). W1-W5 are all `ok`.

## Autopilot patches (adversary)
- `repin.patch`:
  - Visible suite green: `repin.txt:129-259` shows every `test result: ok`, and `cargo test exit: 0`.
  - The re-pinned issuer now verifies: `repin.txt:265` `ok   S2 rotated key, new id #key-2 (Cedar Rowing)`.
  - Still `axis a: FAIL 8/26` (`repin.txt:290`). Red: S3, S4, R2, R3, V3-V7, N1-N5, N7, W2, W4, W5 (`repin.txt:264-289`). The
    Northfield cases S3, R2, V3, N5 and W5 are red; N6 passes.
- `symptom.patch`:
  - Suite green (`symptom.txt:259`) and `ok S2` (`symptom.txt:265`).
  - Still `axis a: FAIL 9/26` (`symptom.txt:290`). V2 shows that `resolve_issuer` still returns Cedar
    Rowing's stale `#key-1` snapshot. Red: S3, S4, R2, R3, V2-V7, N1, N2, N5, N7, W2,
    W4, W5 (`symptom.txt:264-289`).
- `ticket-1.patch`: suite green (`ref.txt:260`), `axis a: PASS 26/26` (`ref.txt:291`).

## Verdict against D13 (T1)
- **Holds:** the symptom and re-pin patches stay red.
- **Does not hold:** a casual run leaves axis (a) red. The cold agent read `did-web-method.md` on its
  6th tool call. It checked the hosted-bucket layout against the resolver's URL builder, and it
  fixed the path mapping unprompted. N21's plant is visible to any agent that reads `reference/`, and a
  casual opus run does read it.

## Try 1
Try 1's artifacts (void run, cold run, patches, outputs, summary) are in `try1/`. See
`try1/summary.md`: that run got `axis a: PASS 21/21` on the pre-N21 tree.
