# Credentials practice, built in the cloud with agent-verified traps
status: RUNNING
created: 2026-09-27 · updated: 2026-09-28
goal: practices/credentials/ is a runnable, graded, proof-recorded Cedar practice built from its DESIGN.md (practices/credentials/DESIGN.md:1-524), orchestrated from a Claude Code cloud session, Ticket 1's FM-13 trap is verified by the contract test (generator/CONTRACT.md:174-176; D13 T1), and Ticket 2 and the feature trap are each shown to bite a real cold agent
verify: bash .plan/2026-09-27-credentials-practice-cloud-build/scripts/verify.sh
commit: per-node
budgets: 2 tries per brief · 2 replans per node

## Decisions

- D1 Build fresh from main with DESIGN.md as the blueprint. The stale branches (credentials-practice-build, credentials-build-plan, claude/credentials-build; their large up-front BUILD-CONTRACT got stuck at BLOCKED) are prior art to read, not to resume | confirmed · recommend: fresh · alt: resume credentials-practice-build
- D2 Target Context cedar@1.2.0, the current version (context/cedar/CHANGELOG.md:16). This brings in the paired naive-vs-elicited feature proof, examiner-only robustness probes and feature-reference/ | confirmed · recommend: cedar@1.2.0 · alt: cedar@1.1.0 as DESIGN.md:12 says
- D3 N01 and N02 run locally. Everything else runs in one Claude Code cloud session on the repo, started by pasting START-PROMPT.md. That needs repo-local copies of the run-plan and new-plan skills and the executor, verifier and planner agents under .claude/, rewritten to repo-relative paths so the run works with an empty user-level Claude dir, plus a run-plan override that bootstraps toolchains on start and pushes after every commit | confirmed · recommend: as stated · alt: run everything locally
- D4 N03 is the one live gate. The human pauses the local run and pastes START-PROMPT.md into a cloud session, and the cloud orchestrator marks N03 DONE on its first read | confirmed · recommend: keep live (a physical hand-off)
- D5 Assume the cloud environment's default network reaches rustup, crates.io, pub.dev and the Flutter SDK storage. bootstrap.sh probes each one. If any is blocked, the human switches the environment's network to Full at N03 | confirmed · recommend: as stated
- D6 All work happens on a new branch, credentials-cloud-build, which N01 creates. The plan dir, .claude/ and run artifacts live only there. N18 merges the practice and the harness changes into main without .plan/ and .claude/, pushes, and deletes the branch. The user set the precedent in 18f3f52 | confirmed · recommend: pre-authorize branch, pushes and merge · alt: work on main (AGENTS.md default)
- D7 After the merge, N18 deletes the three stale credentials branches (credentials-practice-build, credentials-build-plan, claude/credentials-build) both locally and on the remote. The deletion is pre-authorized, and until then they stay readable as D1 prior art | confirmed · recommend: N18 deletes them · alt: leave untouched
- D8 Executors choose pins for the latest stable Rust and Flutter plus the Affinidi crates and packages (DESIGN.md:400-421), each verified live to exist (FM-08), with no human pin approval | confirmed · recommend: pre-authorize · alt: a human pin gate
- D9 Hermetic grading: commands.install fetches against committed lockfiles, and test and grade then run offline. No vendored dependency trees are committed | confirmed · recommend: as stated · alt: cargo vendor plus a committed pub cache (DESIGN.md:417)
- D10 Grade axis (b) runs hidden tests under headless `flutter test` (no device, no integration_test/). The cross-stack check sends VP JSON to a hidden backend verifier bin | confirmed · recommend: as stated · alt: `flutter test integration_test/` (DESIGN.md:366; needs the Linux desktop toolchain plus xvfb in the cloud)
- D11 Reference fixes ship as _solutions/reference-fix/ticket-1.patch and ticket-2.patch, plus _solutions/feature-reference/, so bite checks can apply them mechanically | confirmed · recommend: as stated · alt: FIX.md prose only
- D12 The real agent is a headless `claude -p --model opus` that the verifier launches through Bash. It runs in a harness-shaped clone outside the repo, built per AGENTS.md rules 1-4 with DESIGN.md also stripped, with web tools off and the transcript audited. Any access outside the clone voids the run. If `claude -p` can't authenticate in the cloud, N05 reports BLOCKED | confirmed · recommend: as stated · alt: sonnet as the cold model
- D13 What "the trap works" means, with one cold run per check and artifacts committed under .plan/<dir>/runs/<node>/, the only place a check may write:
  - T1 (amended by D21): the contract FM-13 test (generator/CONTRACT.md:174-176). The symptom-patch and re-pin patches stay red and only ticket-1.patch goes green. The cold casual run is recorded as FM-16 evidence, not required to stay red.
  - T2: runs from the reference T1 fix. A casual run leaves axis (a2) red, each single-axis patch stays red, and all four together go green.
  - Feature: a naive run fails the feature cases, and both the elicited run and the reference pass them.
  | confirmed · recommend: as stated · alt: 2 cold runs per check
- D14 If a trap doesn't bite, a replan may strengthen it by tightening graded cases or removing coaching. It may never weaken a grader | confirmed · recommend: pre-authorize
- D15 FEATURE-REQUEST.md drops the ⚠️ hint (DESIGN.md:317-318), because it breaks invariant 10 (generator/CONTRACT.md:174) | confirmed · recommend: drop
- D16 N15 deletes practices/credentials/DESIGN.md once its content has been moved into README.md and _solutions/. A cloned practice would otherwise be coached by it | confirmed · recommend: delete · alt: move it into _solutions/
- D17 If N16 finds the practice over-scoped, only the cross-stack check drops to test level. The feature cases stay graded | confirmed · recommend: pre-authorize · alt: ask the human
- D18 The proof comes from an agent-driven train run labelled as a calibration run (AGENTS.md rule 10) and saved as _solutions/proof-train-<date>.html. The control run gets both tickets (DESIGN.md:516) | confirmed · recommend: as stated · alt: a human-driven proof later
- D19 Models: sonnet executors for mechanical work, opus for planting traps and for judgement, opus verifiers, opus orchestrator | confirmed · recommend: as stated
- D20 (N11 replan) Ticket 1 did not bite a cold opus (runs/N11/summary.md). The agent read reference/ unprompted and deleted the snapshot early return (backend/src/verifier.rs:197-204), which falls straight through to a did:web resolver that already meets the spec. So reference/ adds nothing that a fix from the code alone lacks, and DESIGN.md:259-261 ("a fix that never read reference/ fails them") is false. D14's two levers cannot close this gap:
  - The only coaching left to remove is the comment on the stale branch (verifier.rs:198-200). The ticket's "not just the ones who complained" is required by the template (context/cedar/templates/FILES.md:69-70).
  - The grader has no reference-derived case that the from-code fix misses. It builds its did:web URLs with the backend's own did_web_url (_solutions/grader/src/main.rs:134,155,165).
  Recommend strengthening the plant with a new fix node before N11:
  - (1) Plant one spec gap in the live did:web path that the visible suite and the onboarding data never exercise, and that hits a rotated onboarded issuer: path-DID URL mapping (Northfield, `…:chapters:north`, reference/did-web-method.md §3.2). Drop the visible path-DID assertion at backend/tests/resolver.rs:100-104.
  - (2) Tighten the grader so it derives URLs from the spec, not from did_web_url.
  - (3) Move the "peer DIDs" drift comment off the stale branch.
  - (4) ticket-1.patch also fixes the mapping (still backend/src only, under 60 lines).
  - Pre-checks: the recorded cold diff goes FAIL; repin, symptom and the reference fix behave as before; the ticket-2.patch composition still holds; feature-reference axis b PASS. N14's cold run stands. Then N11 re-runs after N20.
  | confirmed · recommend: as stated · alt A: move the comment only, then re-run (within D14, unlikely to bite) · alt B: keep the plant and amend D13 T1 so Ticket 1 is claimed as a warm-up, not a verified trap · alt C: cold T1 on sonnet (D12 alt)
- D21 (N11 replan 2) Even after N21's plant, a clean cold casual opus read reference/did-web-method.md on its 6th call and converged (runs/N11/summary.md, `axis a: PASS 26/26`). D14 has no lever left that doesn't punish the research the practice rewards. Proposal: align D13 T1 with the contract's own FM-13 test (generator/CONTRACT.md:174-176). The trap is verified when the symptom and re-pin patches stay red and only ticket-1.patch goes green. That is already met: repin FAIL 8/26, symptom FAIL 9/26, ref PASS 26/26 (runs/N11/summary.md).
  - The cold run is kept as FM-16 evidence ("a researched run converges"). It is not a bite.
  - N15's trap-manifest and README claim the Ticket 1 plateau only in CONTRACT.md:30-32 terms (measurable when the fix prompt comes before the research pass). They never say a cold agent falls into it.
  - N11 closes on the committed evidence, with no re-run. Ticket 2 (N14) stays the trap that is shown to bite a real cold agent.
  | confirmed · recommend: as stated · alt A: cold T1 re-run on sonnet (D12 alt), falling back to this if it converges · alt B: plant again (N11 has no replans left)

## Graph

| id | title | type | deps | model | try | rp | status | note |
|----|-------|------|------|-------|-----|----|--------|------|
| N01 | branch + cloud kit + verify.sh (local) | exec | - | sonnet/opus | 1 | 0 | DONE | |
| N02 | harness: ordered ticket queue (local) | exec | - | sonnet/opus | 1 | 0 | DONE | |
| N03 | human: start cloud session | gate | N01,N02 | -/- | 0 | 0 | DONE | |
| N04 | toolchains, pins, package skeletons | exec | N03 | sonnet/opus | 1 | 0 | DONE | |
| N05 | cold-agent kit + smoke run | exec | N03 | opus/opus | 1 | 1 | DONE | |
| N06 | backend core + Ticket 1 plant + reference DIDs | exec | N04 | opus/opus | 1 | 0 | DONE | |
| N07 | wallet app + FEATURE-REQUEST | exec | N04 | opus/opus | 1 | 0 | DONE | |
| N08 | axis (a) grader + grade.sh + T1 ref fix | exec | N06 | opus/opus | 1 | 0 | DONE | |
| N09 | webhook notifier + Ticket 2 plant | exec | N06 | opus/opus | 1 | 0 | DONE | |
| N10 | axis (b) feature gate + feature-reference | exec | N06,N07 | opus/opus | 1 | 0 | DONE | |
| N20 | cold kit fix: toolchain PATH, CLI files in clone, heredoc audit | exec | N05 | opus/opus | 1 | 0 | DONE | |
| N21 | Ticket 1 plant: path-DID gap + spec-derived grader | exec | N08,N10,N12 | opus/opus | 1 | 0 | DONE | |
| N11 | Ticket 1: FM-13 trap verified on committed evidence | check | N05,N08,N20,N21 | -/opus | 2 | 2 | DONE | |
| N12 | axis (a2) grader + T2 ref fix | exec | N08,N09 | opus/opus | 1 | 0 | DONE | |
| N13 | real agent: feature naive vs elicited | check | N05,N08,N10,N20 | -/opus | 1 | 1 | DONE | |
| N14 | real agent: Ticket 2 bites | check | N05,N12 | -/opus | 1 | 0 | DONE | |
| N15 | README, practice.json, examiner docs, probes | exec | N11,N13,N14 | opus/opus | 2 | 0 | DONE | |
| N22 | scrub clone taxonomy tags + leak guard scans taxonomy | exec | N15 | sonnet/opus | 1 | 0 | DONE | |
| N16 | fresh reviewer: solvable at XL | check | N15,N22 | -/opus | 1 | 1 | DONE | |
| N17 | control run + calibration train proof | exec | N16 | opus/opus | 2 | 0 | BLOCKED | blocked: re-driving the train run refused by permission classifier (transcript tampering); needs human |
| N18 | merge into main + delete stale branches | exec | N17 | sonnet/opus | 0 | 0 | TODO | |
| N19 | plan acceptance (CONTRACT checklist) | check | N18 | -/opus | 0 | 0 | TODO | |
