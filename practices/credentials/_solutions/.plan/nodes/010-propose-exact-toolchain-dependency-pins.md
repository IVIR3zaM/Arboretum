# 010 — Propose exact toolchain + dependency pins

Role: worker · Tier: fast · Phase: P0 · Deps: —

## Goal
Nothing is installed into the repo. Research only: turn DESIGN.md's Affinidi section into exact, verified-to-exist pins (DESIGN names the Dart libs by repo name; the real pub names are `ssi` and `dcql`). This file is what the human approves at gate 015.

## You may read
- `practices/credentials/DESIGN.md`
- `practices/credentials/_solutions/.plan/VERIFICATION.md`
- `practices/credentials/_solutions/.plan/logs/005/baseline.txt`

## You may write
- `practices/credentials/_solutions/.plan/digests/deps-pins.md`
- `practices/credentials/_solutions/.plan/logs/010/**`
- `practices/credentials/_solutions/.plan/logs/010/**` (raw output)

## Acceptance criteria
- A1 (V4): digests/deps-pins.md lists exact versions for: rust toolchain (>= affinidi-did-common MSRV 1.95.0), affinidi-did-common, Flutter SDK (whose bundled Dart satisfies `ssi`'s sdk constraint), pub `ssi` and `dcql` (publisher affinidi.com), each with a captured registry lookup under logs/010/
- A2 (V4): The deny-list (affinidi-did-web, affinidi-did-webs, affinidi-did-resolver-*, affinidi-tdk, any other did:web resolver) is checked against the FULL transitive tree of the proposed crates (`cargo tree` in a throwaway crate under $TMPDIR) and pub deps; result captured; zero hits or an explicit substitution
- A3 (V4): An API sketch names the exact types/functions used: affinidi-did-common DID Document + verification-method types; `ssi` VC/VP construction + signing; `dcql` query evaluation. Every name is cited to docs.rs / pub.dev API docs for the pinned version

## Verify
Command: `test -s practices/credentials/_solutions/.plan/digests/deps-pins.md`
Judged by: node 011 (reads artifacts on disk, never your summary)

## Rules
- Never run git yourself. Make state changes durable only through `bash practices/credentials/_solutions/.plan/scripts/sync.sh ...`, and run `sync.sh checkpoint` at the end of every round.
- Never make a deliberately wrong edit in `practices/credentials/`. Throwaway copies go in `.sessions/build-credentials/010/` (not durable: copy any result you need into `practices/credentials/_solutions/.plan/logs/010/`).
- Never weaken a grader or fit a check to make something pass. If the honest result is red, hand off blocked with the log path.
- Nothing you write inside the learner-cloned tree (source, tests, READMEs, reference/, tickets) may narrate a defect, a suite blind spot, or the grader (invariant 12).

## Stop rule
max_rounds: 6. On exhaustion complete as `blocked` with the last failing output path. Do not expand scope to make progress feel like it is happening.

## Handoff
`bash practices/credentials/_solutions/.plan/scripts/sync.sh complete 010 --status <status> --summary "<=200 tokens" --artifacts "..." --logs "..."`
