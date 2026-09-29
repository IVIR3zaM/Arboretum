# Ordered transcript — credentials, TRAIN mode (calibration run)

Learner prompts and trainer notes written by the operator, who had golden access (AGENTS.md rule 10): this is a **calibration run**, not a learner grade. Assistant: a cold `claude -p --model opus` session in `/tmp/cold-N17-train3` (outside the repo), resumed turn after turn. Checkpoints are the outcome checker's runs of practice.json's commands.install/test/grade on a throwaway copy; the assistant never saw a score. Verbatim sources: `train/turn-NN/` (prompt.txt, transcript.jsonl, audit.txt, diff.patch), `train/checkpoints/*/` (unit.txt, grade.txt), `train/trainer/`, `train/staging.txt`.


### Checkpoint `00-baseline` (outcome checker, 2026-09-29T09:52:23Z)

```
backend: 68 passed, 0 failed · app: +20: All tests passed! · test exit: 0
axis a: FAIL 6/26
axis a2: FAIL 4/17
axis b: FAIL 0/7
worst-case: FAIL
```

## Turn 1 (2026-09-29T09:50:07Z)

### Learner prompt

> I'm picking up this repo today and there's a support ticket waiting (TICKET-1.md), but before anyone touches code I want us both to understand the system. Please don't edit any source, test or README yet: this pass is reading only, plus one notes file.
>
> 1. Map both packages for me: in backend/, the path a credential takes from issuance to the door's verify decision (how an issuer is resolved, which keys count, what gets checked), and the status-change webhook notifier. In app/, the wallet's store and the presentation stub. Cite files and functions.
> 2. Read everything under reference/ (every file, including infra/ and the hosted documents). It's the external documentation we have from the other teams and the platform. Write what you learn to research-notes.md at the repo root: for each document, the rules it states that our code has to obey, and wherever the code does something different, say so and cite both sides.
> 3. Reconcile the docs: compare what backend/README.md, app/README.md and the code comments claim with what the code actually does. List each claim that's stale or wrong, and say which source wins and why.
>
> Keep the notes factual and short. Where you're guessing, say so. Finish with a short summary of the three or four things most likely to matter for TICKET-1, but don't propose or make a fix yet.

### Assistant — final reply (13 tool calls; `audit: clean — 13 tool call(s) checked, clone /tmp/cold-N17-train3`)

> Of the rejected clubs, the cause I'd put first is that the door checks each issuer's keys against a copy of its DID document saved at onboarding, never the document the issuer serves today. Three of the four approved issuers have changed their keys since then.
>
> I didn't touch any source, test or README file. The only new file is `research-notes.md` at the repo root; it has the full map with line citations, each reference doc's rules and where the code differs, and the stale-claims table. To check things by running them rather than just reading, I ran both test suites (backend 68 passed, app 20 passed). I also built a throwaway crate in the scratchpad that resolves every approved issuer against the hosted documents in `reference/`.
>
> **1. Map (short version)**
> - **Credential path:**
>   - `onboard` (`backend/src/issuer.rs:20`) resolves the issuer's DID and saves a full copy of its document. At startup the same records load from `data/onboarded-issuers.json`.
>   - `Issuer::issue` (`issuer.rs:104`) signs the credential.
>   - At the door, `Verifier::verify_presentation` → `verify_credential` (`backend/src/verifier.rs:104,155`) runs the checks.
>   - `resolve_issuer` (`verifier.rs:197`) **returns the saved copy for any approved issuer** and only fetches the live document for issuers it doesn't know.
>   - A key counts only if it's listed under `assertionMethod` in that document. The signature is checked only when the proof type is `Ed25519Signature2020`; any other proof type skips the check.
>   - After the signature come the date window and a revocation check against the service's own in-memory store.
>   - Nothing asks the trust registry, and the credential type is never checked.
> - **Notifier** (`backend/src/notifier.rs:136`): it sends one change at a time, in order, first to a built-in "canary" subscriber at `https://example.com/…` and then to the issuer's subscribers. It reads all of the issuer's settings page by page instead of using the index built for this, never retries, and drops whoever is left when its 10-second budget runs out. Health only reflects the canary.
> - **App:** `CredentialStore` only keeps credentials in memory. `WalletService.createPresentation` isn't implemented yet (it throws). `PresentationRequest` reads the request but nothing uses it. The test fixture's credential format doesn't match what the backend issues.
>
> **2. Where the code breaks the reference docs**
> - **did:web spec:** the code builds the wrong address for DIDs that include a path (`backend/src/resolver.rs:94` always inserts `/.well-known`), and it never re-reads a document after onboarding.
> - **Trust registry contract:** it says relying parties must not keep their own list of trusted issuers, and ours does exactly that.
> - **Webhook deployment config:** the 10-second budget equals the platform's hard kill time, and nothing is retried at any layer.
> - **Reserved-domains standard:** `example.com` is used as a live health-check target.
>
> **3. Stale docs:** 13 claims are wrong or stale. The main ones:
> - The backend README says issuers are `did:key` and need no lookup (they're all `did:web`).
> - It says credentials are single-use (the code only blocks a repeated request id).
> - It says notifications are sent concurrently and retried (they're neither).
> - The comment on `Store::onboarded_issuer` claims the saved copy is all verification needs.
> - The app README says credentials are JWTs stored on the device (they're JSON objects held in memory).
>
> On what the system *does*, I treated the code as right. On what it *should* do, the reference contracts win over our own README and comments.
>
> **Most likely to matter for TICKET-1**
> 1. **Saved document copies.** Checking each approved issuer against the hosted documents:
>
>    | Issuer | Result |
>    |---|---|
>    | Harbour Club | matches, which explains why older members verify fine |
>    | Cedar | changed key (`key-1` → `key-2`); should fail as an unknown key |
>    | Kestrel | changed key (`key-2025` → `key-2026`); should fail as an unknown key |
>    | Northfield | same key name, different key; should fail as a bad signature |
>
>    I'm guessing that the "re-approved batch" means these key changes; the storage bucket's version history would show when each one happened.
> 2. **Northfield can't be looked up live at all,** because of the path bug. Switching to live lookups alone won't fix it, and re-approving it through `onboard()` fails too.
> 3. **"Approved" should mean the trust registry says so, not our local list.** Some of the current checks are also too loose (the skipped signature check, and unknown issuers passing via the live-lookup fallback). Any change to how issuers are looked up needs to watch that it doesn't start accepting too much.
> 4. **Why nobody can reproduce it:** every backend test signs as Harbour, and there are no tests for a changed key, a DID with a path, or any other issuer. The notifier problems are real, but I believe they're unrelated to the door rejections.
>
> I haven't proposed or made a fix.


## Turn 2 (2026-09-29T09:55:20Z)

### Learner prompt

> Thanks, I read research-notes.md. Here's my model of TICKET-1 in my own words, tell me where it's wrong before we go further:
>
> The door decides an issuer's key is valid by looking it up in the issuer's DID document. Our issuers are did:web, and a did:web document is whatever the issuer hosts right now: it can rotate keys and move endpoints, which is the whole point of the method. But resolve_issuer short-circuits every approved issuer to the copy we saved at onboarding, a leftover from when issuers were self-contained DIDs where a saved copy never goes stale. So any club that rotated after onboarding ("re-approved") gets its members refused, and Harbour looks fine only because it never rotated. On top of that, our URL builder maps a DID with a path the wrong way compared to the method spec, so for a path DID even a live lookup would miss the document. The fix belongs at the root (resolve the current document, and map the URL the way the spec says), not in re-saving one club's copy or special-casing the clubs that complained.
>
> Before anything is fixed, I want to see it fail. Write failing tests in backend/tests/ that reproduce the ticket the way a member would hit it: a credential signed with the key an issuer publishes today, refused at the door. Cover every approved issuer state you found (never rotated, rotated to a new key id, same key id with new material on a path DID, rotated with a moved endpoint), plus a credential signed with a key the issuer has retired, which must still be refused, and the URL mapping examples from the spec. Serve the hosted documents from the test the way the existing tests fake the network; no real network.
>
> Don't change anything under backend/src/ in this step. Run the suite and show me the actual output: which of the new tests fail, with what error, and that the old tests still pass.

### Assistant — final reply (4 tool calls; `audit: clean — 4 tool call(s) checked, clone /tmp/cold-N17-train3`)

> The ticket now fails in tests the way a member hits it. There are 7 new tests: 6 fail and 1 passes, and all 68 existing tests still pass. Nothing under `backend/src/` changed. The only changes are the new `backend/tests/door.rs` and two tests added to `backend/tests/resolver.rs`.
>
> **Where your model is off**
> - **"Re-approved" meaning "rotated its key" is my guess, not established.** The repo shows three issuers now host different keys than their saved copies, not when they changed or that they are the ticket's batch.
> - **The fix will refuse some credentials that pass today.** Credentials signed with a key the issuer has since retired are accepted now, because the saved copy still lists that key. The retired-key test below shows it. After the fix, anyone still holding one needs a new credential, so support should expect that.
> - **In the contracts, "approved" means the trust registry authorizes the issuer, not our saved list.** Resolving the current document fixes the rejections, but the list stays our trust gate.
> - **Kestrel's moved endpoint doesn't cause a rejection.** It only changes the issuer website shown to door staff.
>
> **How the tests work**
> - Each door test issues a credential, has a member present it, and runs `verify_presentation` against the real `data/onboarded-issuers.json`.
> - The network is faked with `StaticTransport`, serving each hosted document at the address the spec maps its DID to.
> - We only have Harbour's private key. For Cedar, Northfield and Kestrel, the test serves the real hosted document with just the public key replaced by a test key; the DID, key ids and services are unchanged.
> - Each test first asserts the issuer's state (for example, "Cedar rotated to `#key-2`"), so a later sync of `reference/` that changes it will fail with a clear message.
>
> **Results**
>
> | Test | Result | Error |
> |---|---|---|
> | Harbour, never rotated | passes (control) | – |
> | Cedar, rotated to a new key id | **FAILS** | `UnknownKey("did:web:issuer.cedarrowing.example#key-2")` |
> | Northfield, path DID, same key id with a new key | **FAILS** | `BadSignature("signature does not match")` |
> | Kestrel, rotated and moved endpoint | **FAILS** | `UnknownKey("did:web:badges.kestrel-league.example#key-2026")` |
> | Cedar credential signed with retired `#key-1` must be refused | **FAILS: accepted today** | `got Ok(VerifiedPresentation { … issuer: "did:web:issuer.cedarrowing.example" … })` |
> | Spec URL examples (`resolver.rs`) | **FAILS** on 3 of 5 | `w3c-ccg.github.io:user:alice` → `…/.well-known/user/alice/did.json`; `example.com%3A3000:user:alice` → `…:3000/.well-known/user/alice/did.json`; Northfield → `…/.well-known/chapters/north/did.json` |
> | Every approved issuer resolves live from the hosted documents | **FAILS** | `did:web:guild.northfield.example:chapters:north: no document at https://guild.northfield.example/.well-known/chapters/north/did.json` |
>
> The two spec examples without a path (bare domain, and domain with port) map correctly.
>
> The retired-key test fails in the opposite direction from the others: the door accepts a key the issuer no longer publishes. That's the flip side of the same saved-copy problem.
>
> Northfield's door test serves the document only at the spec's address. So once the saved copy is out of the way, it passes only if the URL builder is fixed too.
>
> Existing tests: credential 7, did_document 1, issuer 9, notifier 6, resolver 13, settings 4, status 7, store 5, verifier 16. All pass.


## Turn 3 (2026-09-29T09:57:52Z)

### Learner prompt

> Good, that's the failure I wanted to see. Decisions from my side:
>
> - Refusing credentials signed with a retired key is correct and intended: the ticket's promise is about valid credentials, and a key the issuer no longer publishes is not one. I'll tell support to expect re-issues.
> - The trust-registry question is real but it's not this ticket. Keep the saved list as the gate for "approved" for now; I'll raise the registry with the owning team. Same for the proof-type skip you spotted: note it, don't fix it here.
>
> Now fix TICKET-1 at the root, minimally: resolve_issuer must use the document the issuer serves now (the approved list still decides who is approved), and did_web_url must map DIDs the way the method spec says. Don't re-pin or edit data/onboarded-issuers.json, don't special-case any issuer, don't hard-code keys from reference/. Correct the stale comments on the code you change so they stop claiming the saved copy is enough. No other refactors.
>
> Then run the whole backend suite and the app suite, and paste the real result lines: every test you added in the last step should now pass, and nothing else should have changed. Tell me which of your new tests would still pass if someone reverted only the URL mapping, and which if they reverted only the resolve change, so I know each half is actually covered.

### Assistant — final reply (6 tool calls; `audit: clean — 6 tool call(s) checked, clone /tmp/cold-N17-train3`)

> TICKET-1 is fixed at the root. Members whose credential is signed with the key their club publishes today are now admitted, including Cedar, Northfield and Kestrel. A credential signed with a retired key is refused. Both suites pass with nothing else changed, and each half of the fix has at least one test that fails without it.
>
> **The change** (3 files under `backend/src/`, 12 lines added, 8 removed):
> - **`verifier.rs`, `resolve_issuer`:** it now always resolves the DID's current document; the saved-copy shortcut is gone. Its doc comment now says the onboarding copy isn't used and that a retired key doesn't verify.
> - **`resolver.rs`, `did_web_url`:** it adds `/.well-known` only when the DID has no path, as the spec says. The doc comment now describes that mapping.
> - **`store.rs`, comment on `onboarded_issuer`:** it no longer claims the saved copy is all verification needs. The code there is untouched.
>
> I didn't change `data/onboarded-issuers.json` or any README, and there are no per-issuer cases or copied keys.
>
> **One thing to decide.** You said the approved list should still decide who is approved, but at the door it doesn't anymore. Issuers not on the list already fell back to a live lookup (the old `verifier.rs:201`), and now listed issuers do too. So the list no longer changes any verification result; only `onboard()` uses it. I kept the unlisted-issuer path as it was, because refusing unlisted issuers is new behaviour. It would be a small change in `resolve_issuer` (refuse when `store.onboarded_issuer(did)` is `None`). I'd do it now if you meant the list as a real gate, or leave it with the registry question. I haven't touched the proof-type skip.
>
> **Results after the fix (real lines):**
> ```
> tests/door.rs      test result: ok. 5 passed; 0 failed
> tests/resolver.rs  test result: ok. 15 passed; 0 failed   (incl. did_web_maps_the_method_spec_examples, did_web_resolves_every_approved_issuer_from_the_hosted_documents)
> tests/credential   ok. 7 passed · did_document ok. 1 · issuer ok. 9 · notifier ok. 6
> tests/settings     ok. 4 passed · status ok. 7 · store ok. 5 · verifier ok. 16
> app: 00:03 +20: All tests passed!
> ```
> That's 75 backend tests (the 68 existing plus 7 new) and 20 app tests. There were no compiler warnings.
>
> **Which new tests catch which half.** I checked this by running rather than predicting: I put each half back to the original code in a scratch copy of the backend and ran the new tests.
>
> | New test | Still passes if only the URL fix is reverted? | Still passes if only the resolve fix is reverted? |
> |---|---|---|
> | Harbour, never rotated | passes | passes (control) |
> | Cedar, new key id | passes | **fails** `UnknownKey(…#key-2)` |
> | Kestrel, rotated + moved endpoint | passes | **fails** `UnknownKey(…#key-2026)` |
> | Retired key refused | passes | **fails**, accepted (`Ok(…)`) |
> | Northfield, path DID, same id with a new key | **fails** `NotFound(…/.well-known/chapters/north/did.json)` | **fails** `BadSignature` |
> | Spec URL examples | **fails** (3 of 5 mappings) | passes |
> | Every approved issuer resolves live | **fails** (Northfield) | passes |
>
> Reverting either half turns at least one test red. Northfield's door test is the only one that needs both halves.
>
> `research-notes.md` still describes the old `resolve_issuer` and URL behaviour, and the backend README's stale claims are unchanged. Nothing is committed.


### Checkpoint `03-after-turn-03` (outcome checker, 2026-09-29T10:02:28Z)

```
backend: 75 passed, 0 failed · app: +20: All tests passed! · test exit: 0
axis a: PASS 26/26
axis a2: FAIL 4/17
axis b: FAIL 0/7
worst-case: FAIL
```

**Staging:** 2026-09-29T10:02:38Z staged TICKET-2.md into /tmp/cold-N17-train3 (before turn 04), after train/checkpoints/03-after-turn-03/grade.txt showed "axis a: PASS 26/26"


### Trainer note

> Good driving on this one: you stated your own model before delegating, watched the failure happen before any fix, and asked for each half of the change to be shown to matter on its own. Keep the same order when the next work item arrives, and measure it against everything the work item promises, not only against the case that was reported.


## Turn 4 (2026-09-29T10:02:52Z)

### Learner prompt

> On your question about the approved list: leave it as it is. Whether an unlisted issuer should be refused at the door is the same trust question as the registry, and I'm taking both to the owning team rather than changing gate behaviour inside a key-rotation fix. Please add a short "open questions / deferred" section to research-notes.md with the registry gate, the unlisted-issuer fallback and the proof-type skip, each one line, and update the notes where they now describe the old resolve and URL behaviour.
>
> TICKET-1 has landed. A second ticket just came in: read TICKET-2.md. Same approach as before, no fixes yet:
>
> 1. Before touching the notifier, go back to reference/ for everything that governs it (deployment config, platform limits, naming rules, anything else that applies) and add a Ticket 2 section to research-notes.md: what the platform actually does to this code at runtime, and where our code or our README assumes something different.
> 2. Tell me what the health check actually checks today, end to end, and whether a green result could coexist with the customer's symptom.
> 3. Reproduce the ticket under the conditions it describes, as failing tests in backend/tests/: a customer with a large account (lots of settings) and a customer where one relying party's endpoint hangs, with the health check green in both. The tests should assert what support says is promised, for every subscriber, not just the one account that complained. Use the budget and limits the platform really imposes, not our own constants. No real network.
>
> Don't change anything under backend/src/ yet. Run the suite and show me the actual output of the new tests.

### Assistant — final reply (17 tool calls; `audit: clean — 17 tool call(s) checked, clone /tmp/cold-N17-train3`)

> TICKET-2 reproduces: both new tests fail with the health check green, which is the customer's symptom. The health check can't catch it, because it tests a single POST to `example.com` that happens before any subscriber is contacted. Nothing under `backend/src/` changed in this step.
>
> **Notes updated** (`research-notes.md`):
> - Every passage that described the old resolve or URL behaviour is now marked **[TICKET-1: fixed]**.
> - **§5 Open questions / deferred:** registry gate, unlisted-issuer fallback, proof-type skip, one line each.
> - **§6 TICKET-2:** the platform limits, the mismatches with our code and README, the health check end to end, and how the reproduction works.
>
> **1. What the platform does at runtime** (from `webhook-config.yaml` and PI-STD-014; nothing else in `reference/` applies):
> - **Hard kill at 10 s**, measured from the start of the invocation, not from when `notify` starts. Our own 10 s timeout starts later, so the platform kills us first, and the "did not finish" log line is probably never written (my guess). With `alarms: []`, the drops are silent.
> - **No retries** (`maximum_retry_attempts: 0`, no failure destination). A missed callback is gone for good, so the relying party only catches up at its next status-list refresh, which matches the ticket.
> - **Only a 2 s *connect* timeout.** An endpoint that accepts the connection and never answers holds the invocation until the kill.
> - **An index exists for this lookup and we don't use it.** The table has a `tenant-kind-index`, but `subscriptions()` reads the customer's entire settings table, 100 per page, before sending anything. So cost grows with the number of settings, and if reading passes 10 s, nobody is told. That matches "never arrive".
> - **The README is wrong on delivery:** it says concurrent and retried, but delivery is sequential with no retries.
>
> **2. What the health check checks today**
> - The canary (`https://example.com/webhooks/status`) is always the **first** POST of every notification, before the customer's settings are even read.
> - `canary_healthy()` reports only whether that one POST got a 2xx.
> - In production that server is run by IANA, outside the platform, which PI-STD-014 forbids.
> - So green means "example.com answered". It says nothing about any subscriber.
> - A green result and the customer's symptom can coexist, and they do in both reproductions.
> - How the platform actually reads this flag isn't in the repo; that's an open question in the notes.
>
> **3. Reproduction** (`backend/tests/notifier_platform.rs`). Each revocation is one invocation, cut off at the `timeout_seconds` read from the config and never retried. The tests assert support's promise for every subscriber, and that the health check is green.
> ```
> test every_other_subscriber_is_told_when_one_endpoint_hangs_while_the_health_check_is_green ... FAILED
> rp-000 hangs: 4 of 4 others never told
> rp-001 hangs: 3 of 4 others never told
> rp-002 hangs: 2 of 4 others never told
> rp-003 hangs: 1 of 4 others never told
> test every_subscriber_of_a_large_account_is_told_while_the_health_check_is_green ... FAILED
> health check green, but 40 of 40 subscribers of did:web:badges.kestrel-league.example were never told of the revocation (first: Some("https://rp-000.relying-party.example/hooks/status"))
> test result: FAILED. 1 passed; 2 failed
> ```
> - The test that passes, `the_platform_limits_are_the_ones_this_suite_runs_under`, checks that the config really says 10 s and 0 retries, and that its page size matches ours.
> - In the hang test, when the last subscriber (`rp-004`) hangs, everyone else is still told, so it has no line in the output.
> - The hang test uses an ordinary 12-setting account, not the one that complained.
> - Every existing test still passes: credential 7, did_document 1, door 5, issuer 9, notifier 6, resolver 15, settings 4, status 7, store 5, verifier 16.
>
> **Caveats on the large-account test:**
> - **Unknown account size:** the real account's settings count isn't in the repo. I chose 25,000 settings and 40 subscribers.
> - **Assumed timings:** the time per page read is the repo's model of the table (50 ms), not a platform figure. The relying party's round trip is the stub's 150 ms.
> - **Threshold is arithmetic, not measured:** under those numbers, 40 subscribers start losing callbacks above about 8,000 settings and lose all of them above about 20,000. The mechanism holds regardless; only that threshold depends on the assumed numbers.
>
> **Other things to know:**
> - The production HTTP client isn't in the repo. If it has a response timeout, the hang case is milder than modelled.
> - You said TICKET-1 has landed, but in this working copy nothing is committed: the TICKET-1 changes, both new test files and the notes are all uncommitted.


## Turn 5 (2026-09-29T10:06:38Z)

### Learner prompt

> Good reproduction. First, housekeeping: commit the TICKET-1 work (the src changes, the door and resolver tests) as one commit, and the notes as a separate one, so TICKET-2's changes are reviewable on their own. Leave the new notifier test uncommitted for now.
>
> Then, before you write any notifier code: from your reproduction and the platform notes, list every separate cause you can see that stops a callback from arriving or makes the health check say green when customers are not being told. For each one, say whether fixing it alone would close the ticket's promise, and why not if not.
>
> Then list the decisions this fix needs that neither the ticket nor reference/ settles, with your proposed answer and who should own it (us, Platform, the relying parties). I'd rather answer those now than find out in review that something was decided silently. Don't implement yet.

### Assistant — final reply (2 tool calls; `audit: clean — 2 tool call(s) checked, clone /tmp/cold-N17-train3`)

> Both commits are on a new branch, `support-tickets`. I didn't commit to `master` because it's the default branch, and there's no remote, so nothing is pushed.
>
> - `b0aa8c7` **Verify issuers against their current did:web document (TICKET-1)**: the 3 `src` files, `tests/door.rs` and `tests/resolver.rs`.
> - `819909d` **Add research notes on the system, reference docs and tickets**: `research-notes.md` only.
> - Left uncommitted: `backend/tests/notifier_platform.rs`, as you asked. `TICKET-2.md` is also still untracked, since you didn't mention it.
>
> ## Separate causes
>
> No single cause below closes the promise on its own. Delivery needs 1, 2 and 3 together; a green that means something needs 6 and 7 together. Without 5, any delivery that fails is lost for good.
>
> **Stop a callback from arriving:**
>
> | # | Cause | Where | Fixing it alone closes the promise? |
> |---|---|---|---|
> | 1 | **Reads the whole settings table before the first POST.** The time grows with the number of settings, and the `tenant-kind-index` goes unused. | `notifier.rs:158-169` | **No.** It fixes the large-account test, but a hung endpoint still blocks everyone after it, and enough subscribers × latency still runs past 10 s. |
> | 2 | **Delivers one subscriber at a time.** One slow endpoint delays everyone behind it, and total time is the sum of all round trips. | `notifier.rs:140-150` | **No.** It fixes the hang test, but a large account still dies during the table read before any delivery starts. |
> | 3 | **No response timeout per call.** The platform has only a 2 s *connect* timeout, so an endpoint that accepts and never answers holds the invocation until the kill. | `dispatch`, `webhook-config.yaml:31` | **No.** Sequential calls with a timeout still add up (N slow endpoints × timeout), and it does nothing for the table read. |
> | 4 | **Our budget is the platform's hard limit but starts later.** The runtime kills us first. Subscribers never attempted aren't recorded, and the "did not finish" log probably never runs. | `notifier.rs:23,152` | **No.** It delivers nothing extra. It only makes drops visible, which is still needed to know whether the other fixes work. |
> | 5 | **No second attempt anywhere.** Nothing retries in code, the platform has `maximum_retry_attempts: 0`, and there's no failure destination. A single 503 or a kill is final. | code + config | **No.** Retrying doesn't help if every attempt dies the same way. And a platform-level retry would re-send to everyone who already got the callback. |
> | 11 | **The canary sits on the critical path.** It's the first sequential POST, to an outside host. The stub answers in 0 ms; in production it costs a real round trip over NAT, and it can hang (cause 3). | `notifier.rs:141-146` | **No.** It's part of causes 2 and 3. |
> | 10 | **Burst limits** (guess, not reproduced): `reserved_concurrency: 20` plus `maximum_event_age_seconds: 60` may drop events when a large league revokes in bulk. | config | **No.** And it's Platform's configuration. |
>
> **Make green lie:**
>
> | # | Cause | Where | Fixing it alone closes the promise? |
> |---|---|---|---|
> | 6 | **Health measures the canary only, and the canary runs before the settings read.** Its result doesn't depend on any subscriber delivery. | `notifier.rs:141-146` | **No.** It delivers nothing. The health flag also needs a meaningful target (7). |
> | 7 | **The canary target is `example.com`.** That's outside the platform and forbidden by PI-STD-014. Tests stub it to answer 200 instantly, so tests can never go red. | `notifier.rs:29`, `webhook.rs:84-87` | **No.** A platform-operated target would still only show that one endpoint is reachable, not that customers are being told (6). |
> | 8 | **Health is a boolean for the last event only, in one process.** A single success erases earlier failures, and with up to 20 instances it depends on which one answers (partly a guess about how the flag is read). | `notifier.rs:109,144` | **No.** Same reason as 6. |
> | 9 | **No alarms** (`alarms: []`), and the per-delivery records are lost when the invocation is killed (4). | config | **No.** It's about detection, not delivery. |
>
> ## Decisions neither the ticket nor reference/ settles
>
> | # | Decision | My proposal | Owner |
> |---|---|---|---|
> | D1 | **What "told" means for an endpoint that never answers or is down.** Taken literally, the promise can't be met for that relying party. | Every subscriber gets a delivery *attempt* within the invocation, with a bounded wait. Anything not acknowledged is recorded as failed, with a reason. The promise becomes: every *reachable* subscriber is told, and every failure is recorded and alerted. | Us, plus Partner Success to reword the promise |
> | D2 | **Retries.** Retrying inside the invocation is limited by the 10 s kill. Durable redelivery needs a queue or failure destination, which means changing `deploy.yaml`, and that file is Platform's. | Now: at most one quick retry inside the invocation for immediate failures, and never re-send to anyone who already acknowledged. Later: ask Platform for a failure destination so failed deliveries can be redelivered durably. | Us for now; Platform for durable redelivery |
> | D3 | **Delivery guarantee: at-least-once or exactly-once.** Retries make duplicates possible. | At-least-once. The payload (`credential_id`, `status_index`, `revoked: true`) is already safe to apply twice. Tell relying parties to expect duplicates. Possibly add an event id; that changes the payload, so they'd need to agree. | Us + relying parties |
> | D4 | **Internal budget and per-call timeout.** The 10 s count starts before our code runs, and the startup overhead is unknown. | Internal budget of about 8 s, leaving room to record who wasn't reached. Per-call response timeout of about 3 s (connect is already 2 s). The exact numbers depend on Platform's cold-start figures. | Us; Platform to confirm the overhead |
> | D5 | **How many POSTs run at once.** It's unbounded today in principle. Up to 20 instances × parallel calls go through shared NAT gateways. | Cap it (e.g. 16 at once per invocation), and state a maximum number of subscribers per customer that we support within the budget. | Us; Platform to confirm NAT connection limits |
> | D6 | **Reading subscribers from `tenant-kind-index`.** A global secondary index is eventually consistent, so a subscription added seconds before a revocation might be missed. Also, the repo can't show that production rows really have `kind = "webhook"`. | Accept the eventual consistency. Confirm the production data with the table owner before relying on the index. | Us; Platform/data owner to confirm the data |
> | D7 | **What green means.** Support says "callbacks are reaching customers". Should one relying party's broken endpoint turn the platform's health red? | Split it. **Notifier health** (ours) means every subscriber was attempted within budget over a recent window, the canary acknowledged, and nothing was dropped for lack of time. **Relying-party failures** are reported per customer and don't flip global health. Support's wording needs to match. | Us + Partner Success; Platform for the probe and alerting |
> | D8 | **Canary target.** PI-STD-014 requires a platform-operated endpoint, reached the same way as real traffic. None is named anywhere. | Ask Platform for an endpoint behind the same public NAT path, and make the URL configurable, not a constant. Until one exists, don't count `example.com` as health. | Platform |
> | D9 | **Alarms.** `alarms: []` lives in Platform's `deploy.yaml`. | We emit metrics for failed, dropped and timed-out deliveries. Platform adds alarms on those and on invocation timeouts. | Platform (config), us (metrics) |
> | D10 | **Revocations already missed.** Since go-live, the league's subscribers have missed every revocation, and fixing the code doesn't send those. | Once the fix is deployed, do a one-off replay of the league's revocations to its subscribers. Meanwhile, support asks those relying parties to refresh the status list now. | Us + Partner Success + the league |
> | D11 | **Endpoints that keep failing.** Should they be flagged, disabled, or reported to the customer? | Out of scope for this ticket. Report it; don't auto-disable. | Us + relying parties (later) |
> | D12 | **Shape of the fix.** Keep one invocation fanning out to everyone, or switch to one queued message per subscriber? | Stay within one invocation now; that's code-only. Raise per-subscriber queuing with Platform as the durable answer (ties to D2). | Us now; Platform for the long term |
>
> The ones I'd most like answered before writing code are D1 and D7, because they decide what the tests assert. D10 needs someone to act regardless of the code fix.


## Turn 6 (2026-09-29T10:17:28Z)

### Learner prompt

> Useful list. I took the open ones to their owners this morning; here's where they landed.
>
> - D1: agreed. Every subscriber gets a bounded attempt inside the invocation; one that doesn't answer in time must show up as a recorded, non-delivered event our monitoring can see, not a log line. Partner Success will reword the promise to "every reachable subscriber".
> - D2/D3: no retries in this fix. The deployment says zero retries and I don't want a retry policy invented inside an incident fix. Durable redelivery (failure destination or a queue) goes to Platform as a follow-up; write it down, don't build it.
> - D4: fine. Keep our whole fan-out comfortably inside the platform's kill with a per-call timeout; don't touch the platform's limit and don't raise our budget constant to paper over it.
> - D5: bounded concurrency is fine; pick a sensible cap and say why.
> - D6: use the tenant-kind index. Platform confirms production rows carry the kind.
> - D7/D8, from Platform: the canary target they operate for this service is a receiver on the instance's loopback, http://127.0.0.1/webhooks/canary, behind the same outbound client as the real calls. The canary must vouch for the real path, so it should go out on the same path as this change's subscribers, after the lookup, and a change whose subscribers could not be read or reached in time must not leave it green. Per-customer relying-party failures come through the delivery events, not the global flag.
> - D9, D10, D11, D12: record them as follow-ups in research-notes.md with their owner. D10 is being handled by Partner Success.
>
> Now implement the TICKET-2 fix, minimal, in the notifier. Keep Notifier's public API (constructor and methods) as it is, since other code and tests construct it. Fix the stale README lines about delivery in the same change. Then:
>
> 1. Run the new notifier_platform tests and the whole backend and app suites, and paste the real result lines.
> 2. Show me the reproduction tests failing on the old notifier and passing on the new one, by actually running them against both, not by reasoning.
> 3. For each cause you listed, point to the line of the diff that addresses it, or say it's deferred.

### Assistant — final reply (16 tool calls; `audit: clean — 16 tool call(s) checked, clone /tmp/cold-N17-train3`)

> TICKET-2 is fixed in `backend/src/notifier.rs`. Both reproduction tests now pass, and every suite is green. Nothing for TICKET-2 is committed yet.
>
> **The change.** The public API is unchanged: the constructor, `with_platform_subscriber`, `canary_healthy`, `notify`, `payload`, and the types and constant names.
> - Subscribers are read through the `tenant-kind-index`.
> - Deliveries run concurrently, at most 16 at a time. Each call gives up after 3 s, and the whole change must finish within 7 s.
> - There are no retries. Every subscriber gets exactly one delivery event, and one that fails, doesn't answer in time, or isn't reached within the 7 s is recorded as `Failed`.
> - The canary is now Platform's receiver at `http://127.0.0.1/webhooks/canary`. It goes out after the lookup, through the same transport as the subscribers.
> - The health check goes red when the subscribers couldn't be read in time or some weren't attempted in time.
> - The README's delivery paragraph is rewritten, and the notes have the follow-ups (with owners) and a TICKET-2 status section.
>
> **Why 7 s, 3 s and 16:**
> - **7 s budget:** the platform kills the invocation at 10 s, counted from its start. 7 s leaves about 3 s for start-up and for recording what wasn't delivered. I lowered our budget constant rather than raising it.
> - **3 s per call:** that's the platform's 2 s connect timeout plus a little time for a response.
> - **16 at a time:** two full rounds of endpoints that never answer (32 subscribers) still fit inside 7 s, and healthy endpoints go through 16 per round trip. Across the 20 instances the deployment allows, that's at most 320 connections through the shared NAT gateways.
>
> **One interpretation to confirm with Platform.** They said a change whose subscribers "could not be read or reached in time" must not leave the check green. I've read that as: not looked up, or not given its 3 s attempt, within our 7 s budget. An endpoint that fails its own 3 s attempt counts as that relying party's failure: it goes in its delivery event, and the check stays green. That's what the hang test asserts.
>
> **1. Results (new notifier):**
> ```
> tests/notifier_platform.rs  test result: ok. 7 passed; 0 failed
> credential ok. 7 · did_document ok. 1 · door ok. 5 · issuer ok. 9 · notifier ok. 6
> resolver ok. 15 · settings ok. 4 · status ok. 7 · store ok. 5 · verifier ok. 16
> app: 00:03 +20: All tests passed!
> ```
> No compiler warnings. I added four tests for what the owners decided:
> - a hung subscriber is recorded as not delivered;
> - the canary receives the same change through the same transport;
> - health isn't green when the subscribers can't be read in time;
> - when the budget runs out, every subscriber not reached is recorded and health isn't green.
>
> **2. The same test file against the old notifier** (a scratch copy of the backend with the committed `notifier.rs` put back):
> ```
> every_subscriber_of_a_large_account_is_told_…            FAILED  40 of 40 subscribers … never told
> every_other_subscriber_is_told_when_one_endpoint_hangs_… FAILED  rp-000 hangs: 4 of 4 others never told … rp-003 hangs: 1 of 4
> a_subscriber_that_does_not_answer_in_time_is_recorded_…  FAILED  exactly one event for the hung subscriber: []
> when_the_budget_runs_out_…                               FAILED  rp-000: expected one failed event, got []
> health_is_not_green_when_the_subscribers_cannot_be_read… FAILED  no canary before the lookup completes
> the_platform_limits_are_the_ones_this_suite_runs_under   ok
> the_canary_goes_out_after_the_lookup_on_the_same_path_…  ok
> test result: FAILED. 2 passed; 5 failed      (old tests/notifier.rs: ok. 6 passed)
> ```
> The last `ok` shows a test of mine claimed more than it checked. It passes on the old code because it only compares the body the canary received with a subscriber's. I renamed it to `the_canary_receives_the_same_change_through_the_same_transport_as_the_subscribers`. The ordering ("after the lookup") is checked by the lookup-timeout test, which does fail on the old code.
>
> **3. Each cause and where the new `notifier.rs` handles it:**
>
> | # | Cause | Addressed by |
> |---|---|---|
> | 1 | Whole settings table read before sending | `:183` `query_kind(tenant, WEBHOOK_KIND)` |
> | 2 | One subscriber at a time | `:195-197`: up to `MAX_CONCURRENT_DELIVERIES` spawned at once (`:51`) |
> | 3 | No response timeout per call | `:230` `timeout(DELIVERY_TIMEOUT, …)` (`:44`) |
> | 4 | Budget equal to the platform kill; drops not recorded | `:39` budget 7 s; `:169` deadline; `:200` `timeout_at(deadline, …)`; `:216-218` records every target not reached as `Failed` |
> | 5 | No retries | **Deferred** (D2/D3, Platform) |
> | 6 | Canary sent first, before the lookup | `:171` lookup first, then `:176` canary joins this change's targets |
> | 7 | Canary target `example.com` | `:59` Platform's loopback receiver |
> | 8 | Health = last canary POST only | `:173` red if the lookup is late; `:178` + `:220` green only if the canary acknowledged and all targets were attempted. Still per process, as designed |
> | 9 | No alarms | **Deferred** (D9, Platform config + our metrics); the events now carry the data |
> | 10 | Burst limits | **Deferred** (Platform) |
> | 11 | Canary on the critical path | Same lines as 2, 3 and 6: it gets a concurrent slot after the lookup, with the same 3 s cap |
>
> **Caveats:**
> - **Health is written only at the end of a change.** If the platform ever killed an invocation before our 7 s ran out, the previous value would stay. The 3 s headroom assumes start-up takes less than that; Platform hasn't confirmed their cold-start figure.
> - **There's a ceiling.** If every endpoint hangs, about 32 subscribers get their full attempt; with healthy endpoints at 150 ms, about 700 do. That's arithmetic, not a measurement. Anyone beyond that is recorded as not delivered and turns the check red rather than failing silently. The per-subscriber queue follow-up (D12) removes the ceiling.
> - **Nothing for TICKET-2 is committed.** Uncommitted: `notifier.rs`, `backend/README.md`, `tests/notifier_platform.rs` and the notes updates. `TICKET-2.md` is still untracked.


### Checkpoint `06-after-turn-06` (outcome checker, 2026-09-29T10:24:06Z)

```
backend: 82 passed, 0 failed · app: +20: All tests passed! · test exit: 0
axis a: PASS 26/26
axis a2: PASS 17/17
axis b: FAIL 0/7
worst-case: FAIL
```

**Staging:** 2026-09-29T10:24:21Z staged FEATURE-REQUEST.md into /tmp/cold-N17-train3 (before turn 07), after train/checkpoints/06-after-turn-06/grade.txt showed "axis a2: PASS 17/17"


### Trainer note

> Asking for the tests to be run against both versions of the code, instead of reasoned about, is what exposed a test that could not have gone red. Make that the standard for every test the assistant adds from here on, and treat a summary of results as a claim until you have seen the command that produced it.


## Turn 7 (2026-09-29T10:24:22Z)

### Learner prompt

> TICKET-2 has landed. Commit the TICKET-2 work on the same branch (notifier, its tests, the README fix and the notes), with a message that says what changed and what's deferred. Commit the two ticket files too so the history says what each change was for.
>
> Next up is a feature: FEATURE-REQUEST.md just arrived. It reads like a small job, and I don't trust that yet. Before any code:
>
> 1. Read how the backend verifier checks a presentation today, end to end (what it requires, in what shape, what it rejects), and the wallet side that exists: the store, the stub, the request type, the key the holder has. Summarise the wire contract the wallet has to satisfy, citing files and lines.
> 2. Then write me the list of questions I need to take to the people who own the answers before this is built: the PM, the verifier team, and Platform. For each question say who owns it and what we'd build differently depending on the answer. Include anything where our own docs and code disagree about how credentials behave.
>
> Don't implement anything and don't answer the questions yourself. I'll bring the answers back.

### Assistant — final reply (3 tool calls; `audit: clean — 3 tool call(s) checked, clone /tmp/cold-N17-train3`)

> The TICKET-2 work is committed. The feature isn't small: the verifier expects a presentation in a shape the wallet doesn't currently hold or produce, and several things it depends on are undecided. I haven't implemented anything and haven't answered the questions.
>
> **The commit:** `4ea1ecb` "Deliver status-change webhooks within the platform's limits (TICKET-2)" on `support-tickets`. It has the notifier, its tests, the README fix, the notes and `TICKET-2.md`. The message says what changed and lists what's deferred, with owners. `TICKET-1.md` was already in the baseline commit, so there was nothing to add for it. `FEATURE-REQUEST.md` is left uncommitted.
>
> ## 1. The wire contract the wallet has to satisfy
>
> **How the door calls the verifier:** `Verifier::verify_presentation(submission, expected_nonce, expected_domain)` (`backend/src/verifier.rs:104`). `Submission` is `{ request_id, presentation }`, and `request_id` is set by the scanner's transport, not by the wallet (`:48-52`). The checks run in this order:
>
> 1. **`request_id` must be new** (`:111`). The replay guard is keyed on this, not on the nonce or the credential.
> 2. **`presentation.nonce` must equal the scanner's nonce** (`:114`). It's a string.
> 3. **`presentation.domain` must equal the scanner's `expected_domain`** (`:117`). It's a string.
> 4. **`presentation.holder`** is a DID string (`:121`). The verifier resolves it and checks `presentation.proof` against the holder's `authentication` keys (`:122-126`).
>    - The proof must have `type: "Ed25519Signature2020"`, a `verificationMethod` listed under `authentication`, and `proofValue`. `proofValue` is base58btc multibase (starts with `z`) of an Ed25519 signature over the RFC 8785 (JCS) form of the whole presentation minus `proof` (`credential.rs:43-52,55-64,67-75`; `verifier.rs:206-237`).
>    - For a `did:key` holder, the key id is `did#<multibase>` (`resolver.rs:154`).
>    - `proofPurpose` and `created` aren't checked. The backend writes `created` as unix seconds (`credential.rs:59`).
>    - **Any other proof type skips the signature check, and so does a holder DID method the resolver doesn't support** (`:208`, `:124`).
> 5. **`presentation.verifiableCredential`** is the credential exactly as issued, as a JSON object (`:128`). `verify_credential` (`:155-194`) requires:
>    - `issuer`, `id` and `credentialSubject.id` strings;
>    - an issuer proof under `assertionMethod` of the issuer's *current* document (`:160-161`, since TICKET-1);
>    - integer unix `not_before` and `expires_at` (`:164-171`);
>    - `credentialStatus.statusListId` and `statusListIndex`, which must be in the **verifier's own in-process store** (`:173-179`).
> 6. **`credentialSubject.id` must equal `holder`** (`:130`).
> 7. **`presentation.disclosures`** is optional. It's a list of `{salt, name, value}`, and each item's digest, `base64url(sha256(JCS([salt,name,value])))` (`credential.rs:36-39`), must be in `credentialSubject._sd` (`:134-149`). A JSON array form probably also parses, because that's serde's default for structs, but that's untested.
> 8. **Not checked at all:** the presentation's `@context` or `type`, any expiry on the presentation itself, and the credential's type.
>
> **The only reference builder** is the test helper `Holder::present` (`backend/tests/common/mod.rs:61-76`). It builds `@context` v1, `type: ["VerifiablePresentation"]`, `holder`, `verifiableCredential`, `disclosures`, `nonce`, `domain`, then signs with `proofPurpose: "authentication"`.
>
> **What the wallet has today:**
> - **Holder key:** `HolderKey` (`app/lib/src/holder_key.dart`) is Ed25519 via `ssi`, with a `did:key` DID. `keyId` = `did#<multibase>` (`:23`), which matches the backend's form. `sign` returns 64 raw bytes (`:25-26`). Nothing in the app yet encodes base58btc or does JCS.
> - **Store:** `CredentialStore` is **in memory only** (`credential_store.dart:5-16`), and that includes the holder key. After a restart the wallet has no credentials and a new DID, which would fail check 6 against any credential re-imported for the old DID.
> - **Credential:** `HeldCredential` holds the VC as a `Map` plus disclosures (`held_credential.dart:36-52`). Disclosures accept objects or arrays (`:9-25`) and serialize as objects (`:31`).
> - **Request:** `PresentationRequest` has `client_id`, `nonce`, `dcql_query` and an optional `response_uri` (`presentation_request.dart:13-33`). `domain` is simply `clientId` (`:41`), which is our assumption. There's no `request_id`.
> - **Stub:** `createPresentation(credentialId, request)` returns `Map<String, dynamic>` and throws `UnimplementedError` (`wallet_service.dart:52-57`). There's no real `IssuerClient`, so nothing shows what production issuance actually returns.
>
> ## 2. Questions for the owners
>
> **PM**
>
> | # | Question | What we'd build differently |
> |---|---|---|
> | P1 | Which claims does the door need to see: just `member`, or also `tier`, name, birth date? Does the member see and approve what's shared each time? | Minimal disclosure only means a simple mapping. Anything more means a consent screen, and a rule for when the request asks for more than the member wants to share. |
> | P2 | Must credentials and the holder key survive an app restart or a new phone? | Yes: secure on-device storage for the key and credentials (keychain/keystore), plus a recovery or re-issue story for new phones. No: presentations break after every restart (check 6), and we should say so. |
> | P3 | Is a credential single-use at the door, as `backend/README.md:32-33` says, or reusable, as the verifier does (replay is only per `request_id`, `verifier.rs:111`)? | Single-use: the wallet marks credentials spent, or needs a fresh credential per visit, and the verifier must change. Reusable: fix the README. |
> | P4 | What happens when a member has several matching credentials, or an expired or revoked one? | A chooser UI, and whether the wallet pre-checks expiry and status before presenting or leaves it all to the door. |
> | P5 | What does "they're in" mean for the member: an on-screen result from the scanner, or nothing? | Whether the wallet needs a response channel back from the scanner. |
>
> **Verifier team**
>
> | # | Question | What we'd build differently |
> |---|---|---|
> | V1 | What exactly goes over the wire: the raw presentation object `verify_presentation` expects, or an OpenID4VP response (`vp_token` keyed by the DCQL credential id, posted to `response_uri`) that the scanner unwraps? | This decides the whole output shape of `createPresentation`, and whether the wallet talks OpenID4VP at all. |
> | V2 | Which value is `expected_domain`, and is it the request's `client_id` (the app assumes so, `presentation_request.dart:41`)? The tests use `door.harbourclub.example`. | If they differ, the request needs a separate domain field, or the wallet will always fail check 3. |
> | V3 | Which proof suite must the holder use: `Ed25519Signature2020` (what the verifier checks), or DataIntegrity `eddsa-jcs-2022` (what the app fixture carries)? Is the proof-type skip (`verifier.rs:208`, deferred in the notes) staying? | Picking a type the verifier doesn't check means **the door accepts the presentation without checking the member's signature at all**. The wallet must use the checked suite, or this feature has to wait until the skip is fixed. |
> | V4 | Is `created` expected as unix seconds (the backend) or ISO 8601 (DataIntegrity)? Is `proofPurpose: "authentication"` required? | These are signed fields, so they must match exactly for the signature to line up. |
> | V5 | Will the scanner's verifier really have the issuer's status lists? Today `is_revoked` reads the verifier's own in-process store (`verifier.rs:175`), so a door running a separate verifier returns `UnknownStatus` for every credential. | If not, every presentation fails at the door no matter what the wallet does. It's a verifier/deployment change, not wallet work. |
> | V6 | How does the DCQL query map to selective disclosure? The fixture asks for path `["credentialSubject","member"]` (`app/test/fixtures.dart:60`), but claims live only as `_sd` digests plus disclosures, not in `credentialSubject`. The fixture's format is `ldp_vc`; the app README says JWT. | This decides how the wallet picks disclosures from a request, and which DCQL format values we accept. |
> | V7 | Is the scanner's request authenticated (signed request, `client_id` scheme), or does the wallet answer anyone who sends one? How long is a nonce valid? | Verifying requests adds request-signature checks and trust anchors. Not verifying means a member can be phished into presenting to a fake scanner. |
> | V8 | Should disclosures travel as objects (what the backend writes) or arrays (which the app also accepts)? | This fixes the serialization and the digest input, which must be byte-identical under JCS. |
>
> **Platform**
>
> | # | Question | What we'd build differently |
> |---|---|---|
> | X1 | How does the request reach the phone, and how does the response go back: QR plus HTTPS to `response_uri`, BLE/NFC, or the scanner's local network? | Completely different transport code, and whether the phone needs connectivity at the door. |
> | X2 | Do door scanners have network access? Since TICKET-1, the verifier resolves each `did:web` issuer live on every check. | If doors are offline or flaky, the verifier needs a cache (allowed up to `Cache-Control` 300 s). That's not wallet work, but "they're in" depends on it. |
> | X3 | What secure key storage and attestation is available and required on the target devices? | Ties to P2: which storage API we use, and whether keys must be hardware-backed and non-exportable. |
>
> **Where our own docs and code disagree about how credentials behave.** Each of these needs a single answer before we build:
>
> 1. **Single-use or reusable** (P3): `backend/README.md:32-33` says single-use; `verifier.rs:111` only blocks a repeated `request_id`.
> 2. **Credential format:** `app/README.md:8-9` says JWT-VCs kept exactly as issued. `held_credential.dart:40` holds a JSON object. The backend issues JSON-LD with an `Ed25519Signature2020` proof (`issuer.rs:125-140`). The app fixture is VC v2 with DataIntegrity `eddsa-jcs-2022` (`fixtures.dart:13-33`).
> 3. **Validity fields:** the backend README says `expirationDate`; the code uses `not_before`/`expires_at` as unix integers (`verifier.rs:164-165`). The app fixture uses `validFrom`/`validUntil` ISO strings (`fixtures.dart:17-18`), which the verifier would reject as malformed.
> 4. **Stored on the device or not** (P2): `app/README.md:4` says credentials are kept on the device; `credential_store.dart` is in memory only.
> 5. **DCQL format:** the fixture says `ldp_vc`, the smoke test uses `jwtVcJson` (`app/test/smoke_test.dart:19`), and the README says JWT.
> 6. **Presentations:** `app/README.md:16` says `WalletService` handles them; the method throws `UnimplementedError`.
>
> **Before building:** V1, V3 and V5 decide whether this can work at all. V1 fixes what `createPresentation` returns. V3 decides whether the door would even check the member's signature, given the deferred proof-type skip. V5 decides whether any presentation can pass a door running its own verifier. P2 and X1 decide most of the effort.


## Turn 8 (2026-09-29T10:26:40Z)

### Learner prompt

> I took your questions to the owners. Answers, as they gave them:
>
> PM
> - P1: The door gets only what the scanner's request asks for, nothing else. Today the door asks for membership; it must not receive the name, member id or birth date. A consent screen is not in v1.
> - P2: Out of scope for this feature; storage stays as it is.
> - P3: Not single-use, not in v1. The README is wrong: a member shows the same credential every visit. The wallet must not delete or "consume" a credential after presenting it.
> - P4: Choosing between several matching credentials is deferred. An expired credential: refuse. Don't build a presentation the door will turn down; raise a WalletException to the caller. Revocation: see V5.
> - P5: The door UI and the "you're in" result are later work, not this feature.
>
> Verifier team
> - V1: createPresentation returns the presentation itself as a JSON map, the object verify_presentation expects. Posting it to response_uri is not part of createPresentation and not part of v1.
> - V2: Yes, domain is the request's client_id. Both the request's nonce and domain go inside the part the holder signs; we reject a presentation whose nonce or domain isn't the one we issued.
> - V3/V4: The wallet signs the presentation itself: Ed25519Signature2020 by the holder's did:key key, verificationMethod = the holder key id, proofPurpose authentication, over the JCS bytes of the presentation without its proof. We also check the credential's subject is the presenting holder. The proof-type skip on our side is ours to fix; don't design around it.
> - V5: Revocation is the verifier's job; the wallet does not check status before presenting.
> - V6/V8: Each disclosed claim travels as the disclosure the issuer handed over, {salt, name, value}, unchanged, next to the unchanged credential. The wallet holds what our backend's Issuer issues (JSON-LD, Ed25519Signature2020, expires_at in unix seconds); the app's fixture and README are out of date.
> - V7: Request authentication is not in v1.
>
> Platform
> - X1: Building the presentation is fully local: credential, disclosures and holder key are all on the device. Transport is not part of createPresentation.
> - X2, X3: not wallet work; out of scope here.
>
> Now build the smallest correct version of WalletService.createPresentation(credentialId, request) to exactly these answers, and nothing the answers defer. Keep WalletService's public API as it is (constructor included). Tests first in app/test/: write tests for each rule above and show them failing against the stub before you implement. Use a credential shaped like what the backend actually issues, not the stale fixture. Then implement, and prove the wire contract end to end: a presentation the wallet builds must be accepted by the real backend Verifier, and tampering with the nonce, the domain or a disclosure must be rejected. If that needs a throwaway cross-check, keep it inside this repo and tell me where it lives or that you removed it. Fix the README lines these answers settle. Paste the real result lines of both suites at the end.

### Assistant — final reply (20 tool calls; `audit: clean — 20 tool call(s) checked, clone /tmp/cold-N17-train3`)

> The wallet can now build a door presentation. `createPresentation` follows the owners' answers, and a presentation it builds is accepted by the real backend `Verifier`. Changing the nonce, the domain or a disclosure gets it rejected. Both suites pass. Nothing is committed.
>
> **Tests first.** `app/test/create_presentation_test.dart` has one test per rule and uses `app/test/backend_issued.dart`, a credential produced by the real backend `Issuer`, not the old fixture. Against the stub, 10 of the 11 failed (with `UnimplementedError`, or "threw UnimplementedError" where a `WalletException` was expected). The one that passed only checks that the fixture holder is the credential's subject.
>
> **The implementation** (`app/lib/src/wallet_service.dart`; public API and constructor unchanged):
> - Looks up the credential. Refuses with `WalletException` if it isn't held, isn't issued to this holder's DID, or has expired (`expires_at` in unix seconds, same cut-off as the verifier).
> - Discloses exactly the claims the request's DCQL query names, as the issuer's `{salt, name, value}`, unchanged. A query with no claims discloses none.
> - Builds `@context`, `type`, `holder`, the unchanged `verifiableCredential`, `disclosures`, `nonce`, and `domain` = `client_id`.
> - Signs with `Ed25519Signature2020`, holder key id, `proofPurpose: authentication`, over the JCS form without the proof. It uses `ssi`'s JCS and base58 helpers, so there's no new dependency.
> - Doesn't touch the store, and doesn't check revocation or send anything.
>
> **End-to-end check against the real backend.** It was a throwaway pair, `crosscheck/` (a Rust crate using the real `Issuer` and `Verifier`) and `app/tool/crosscheck_present.dart` (using the real `WalletService`). **I've removed both; nothing of it is left in the repo.** Output:
> ```
> PASS vp-member.json accepted by the real Verifier: claims disclosed ["member"], values {"member": Bool(true)}
> PASS vp-name.json accepted by the real Verifier: claims disclosed ["name"], values {"name": String("Ada \"Pärk\"\n😀")}
> PASS presented to a scan with another nonce: NonceMismatch
> PASS nonce rewritten after signing: BadSignature("signature does not match")
> PASS presented to another domain: DomainMismatch
> PASS domain rewritten after signing: BadSignature("signature does not match")
> PASS disclosure value changed: BadSignature("signature does not match")
> PASS disclosure added after signing: BadSignature("signature does not match")
> 0 failure(s)
> ```
> The `name` case shows both sides produce identical signed bytes for quotes, newlines, non-ASCII letters and emoji. The rewrite cases fail on the member's signature, so the door really checks it.
>
> **READMEs fixed:**
> - `app/README.md`: the JWT-VC description becomes the backend's actual format. "On the device" becomes "in memory". A Presentations section is added.
> - `backend/README.md`: `expirationDate` becomes `expires_at`. "Single-use" becomes "same credential every visit; only a submission is accepted once".
>
> **Choices the answers didn't settle:**
> 1. **Refuses a credential issued to another holder.** The verifier team said they check this; I applied the PM's "don't build what the door will turn down".
> 2. **Refuses a request for a claim the credential doesn't carry,** rather than silently leaving it out.
> 3. **Refuses request shapes I didn't build for:** more than one credential query, `claim_sets`, and any claim path other than `credentialSubject.<name>`. DCQL `values` constraints, `format` and `meta` are ignored.
> 4. **Doesn't check "not yet valid" (`not_before`).** Nobody mentioned it, though the door would turn such a credential down too.
> 5. **Adds `proof.created` as unix seconds,** matching the backend's own signer. It isn't signed or checked.
>
> **Loose ends:**
> - `app/test/fixtures.dart` is still the stale format, because the older tests use it.
> - `research-notes.md` §3 rows 3, 4, 10, 11 and 12 aren't updated yet.
> - Non-integral numbers in a disclosure (e.g. `1e-7`) might be canonicalized differently by Dart and Rust; neither side is fully RFC 8785 there. Today's claims don't include any.
>
> **Results:**
> ```
> flutter analyze: No issues found!
> app:     00:05 +31: All tests passed!   (20 existing + 11 new)
> backend: credential ok. 7 · did_document ok. 1 · door ok. 5 · issuer ok. 9 · notifier ok. 6
>          notifier_platform ok. 7 · resolver ok. 15 · settings ok. 4 · status ok. 7
>          store ok. 5 · verifier ok. 16   (all "0 failed")
> ```
>
> Uncommitted: `app/lib/src/wallet_service.dart`, both READMEs, the two new test files and `FEATURE-REQUEST.md`.


### Checkpoint `08-after-turn-08` (outcome checker, 2026-09-29T10:36:17Z)

```
backend: 82 passed, 0 failed · app: +31: All tests passed! · test exit: 0
axis a: PASS 26/26
axis a2: PASS 17/17
axis b: PASS 7/7
worst-case: PASS
```

### Trainer note

> You took the open questions to the people who own the answers instead of letting the assistant answer them, and that is the move this phase is about. Before you move on, look at what the assistant decided on its own where those answers were silent: each such choice is either yours to accept out loud or a question to send back.


## Turn 9 (2026-09-29T10:36:31Z)

### Learner prompt

> On the choices the answers didn't settle: 1, 2 and 3 are fine and I accept them as v1 behaviour; write them down in the notes. 4 (not-yet-valid) stays out of v1, deferred on purpose, and 5 is fine. Update the stale rows in research-notes.md. Then commit the feature on the branch as its own commit (wallet, tests, both README fixes, the notes, FEATURE-REQUEST.md).
>
> Now the improvement pass. Both tickets and the feature are done; I want to know what's still wrong before this goes to review. Across both packages, find the highest-value correctness and robustness issues that remain, ranked. Two rules:
>
> - Find, don't recite. Every item must be something you can point at in this code (file and line) and, where it's cheap, demonstrate with a quick probe or a failing test in a scratch location. No generic checklist items that don't map to a line here.
> - Include our own changes. Go through the whole diff since the baseline commit (the resolver, the notifier, the wallet) as critically as the original code: what did we introduce, or apply at one entry point but not another?
>
> For each item: what's wrong, how you know (probe output or reasoning, say which), severity, and whether it's in scope for this branch or should be deferred and to whom. Don't fix anything yet; I'll pick.

### Assistant — final reply (5 tool calls; `audit: clean — 5 tool call(s) checked, clone /tmp/cold-N17-train3`)

> I found 13 issues worth fixing. The top one is critical: anyone can forge a Harbour Club membership that the door accepts, with no keys at all. Nothing is fixed yet.
>
> **Housekeeping.** The feature is committed as `c2bb2ab` on `support-tickets` (wallet, tests, both READMEs, notes, `FEATURE-REQUEST.md`). The notes now record choices 1-3 as accepted v1 behaviour, not-yet-valid as deferred on purpose, and the §1.4/§3 rows the feature settled; rows 1, 2, 9 and 13 are marked still stale.
>
> All probes ran from `review-probe/` and `numbers.dart` in the session scratchpad, using the real backend code; nothing in the repo was touched. "Probe" below means I ran it; "reasoning" means I didn't.
>
> | # | Issue | Evidence | Severity | Scope |
> |---|---|---|---|---|
> | 1 | **Anyone can forge a Harbour membership the door accepts, with no keys.** The verifier checks the issuer's signature only when `proof.type == "Ed25519Signature2020"` (`verifier.rs:208`). And a status index that was never handed out counts as "not revoked" (`status.rs:54`, `store.rs` `is_revoked`), so pointing at Harbour's list with a made-up index works. | **Probe P1:** credential with `issuer` Harbour, `proof: {type: "AnythingElse"}`, `statusListIndex: 99999`, subject = the attacker's own `did:key`, presentation signed by the attacker → `Ok("did:web:members.harbourclub.example")`. The attacker can add any claims, since digests and disclosures are theirs. | **Critical** | Deferred to the verifier team by your earlier decision. I'd escalate it as a blocker before this goes anywhere. |
> | 2 | **Our TICKET-1 change put a live, synchronous network fetch in every door check, with no cache.** `resolve_issuer` resolves on every verification (`verifier.rs:201`), and `DocumentTransport::get` is blocking (`transport.rs:26`). If an issuer's host or the CDN hiccups, all its members are refused, and every scan pays the fetch time. Before our change, approved issuers needed no network. | Reasoning; the production transport isn't in the repo. | **High** | Needs a decision. A cache of at most 300 s is allowed by the did:web spec and matches the hosting headers. Owners: us + verifier team, with Platform on door connectivity (X2). |
> | 3 | **The resolver builds dangerous URLs from attacker-chosen DIDs.** It accepts IP addresses (the spec says a DID "MUST NOT include IP addresses"). Decoded `?`, `#` and `@` change which URL is fetched. Attacker-supplied DIDs reach it through the `holder` field (`verifier.rs:122`) and through the unlisted-issuer fallback (`:201`), so the door can be made to fetch internal addresses. | **Probe P2:** `did:web:127.0.0.1` → `https://127.0.0.1/.well-known/did.json`; `…169.254.169.254:latest:meta-data` → `https://169.254.169.254/latest/meta-data/did.json`; `issuer.example:a%3Fx=1` → `https://issuer.example/a?x=1/did.json`; `issuer.example%23` → `https://issuer.example#/…`; `user%40evil.example` → `https://user@evil.example/…`. | **Medium-high** | In scope for `resolver.rs:87-101` (we touched this function). Removing the fallback itself stays with the deferred trust question. |
> | 4 | **Our TICKET-2 guarantee has a hole: a malformed webhook setting is silently skipped.** `filter_map(Subscription::from_setting)` (`notifier.rs:183`) drops a setting with no usable `url`. That subscriber gets no delivery event and health stays green, which breaks D1 ("every subscriber gets a recorded event"). | **Probe P7:** a setting `{"endpoint": …}` produces no event for `rp-typo`; `health green: true`. | **Medium** | In scope (small). |
> | 5 | **Any credential type opens the door.** The verifier never checks `type` (`verifier.rs:155-194`), and `Issuer::issue` accepts any `credential_type` (`issuer.rs:128`). | **Probe P4:** a Harbour-issued `GuestPass` presented at the membership door → `Ok`. | **Medium** | Defer with the registry/trust question (verifier team, Governance). The registry record is per credential type. |
> | 6 | **Customers' webhook URLs aren't restricted.** `http` and loopback addresses are posted to and counted as delivered. With the canary now on the instance's loopback in production, a customer can point the notifier at loopback services. | **Probe P8:** subscriber `http://127.0.0.1/internal/admin` received the POST and was recorded as delivered. This is inside the hermetic model; the real client isn't in the repo. | **Medium** | Defer: Platform (egress policy) + us (validate where settings are written, or refuse and record in the notifier). |
> | 7 | **The replay guard can lock a member out and grows forever.** The `request_id` is marked as seen *before* any other check, so a failed submission uses it up (`verifier.rs:111`). The `seen_nonces` set is never pruned (`:74-79`). | **Probe P6:** garbage with `req-7` → `Malformed`; then the genuine presentation with `req-7` → `Replay`. The unbounded growth is reasoning. | **Medium-low** | Defer to the verifier team. |
> | 8 | **The last credential in a status list can't be revoked, and revoking it reports success.** `allocate` hands out indexes 1..=capacity (`status.rs:39-40`), so the last one is outside the bitstring. `set` silently does nothing, and `set_status` still returns `true` (`store.rs:102-103`). The notifier then broadcasts `revoked: true` while the door keeps accepting. | **Probe P3:** capacity 8, last index 8, after `set(8, true)`: revoked `false`. | **Low-medium** (only hit at the 131,072nd credential per issuer) | Cheap; in scope, or backend team. |
> | 9 | **Our TICKET-2 change reports canary failures as customer failures.** The canary's delivery event carries the tenant of the change it rode on (`record`, `notifier.rs:224`, called from `fan_out`). Per-customer monitoring, which Platform chose (D7), would blame whichever customer's revocation it was. | Reasoning; P7 shows the canary event among the tenant's events. | **Low** | In scope (small). |
> | 10 | **Backend and wallet format some numbers differently, so the signature wouldn't match.** The backend's canonicalizer (`credential.rs:121-131`) isn't RFC 8785 for very small or very large numbers; the wallet's (`ssi`) is. | **Probes P5 + `numbers.dart`:** backend `1e-7` → `0.0000001`, `1e21` → `1000000000000000000000`; wallet → `1e-7`, `1e+21`. A numeric claim in that range would make every wallet presentation fail with `BadSignature` (reasoning; not run end to end). No claims today are numeric. | **Low** | Defer (backend). |
> | 11 | **The wallet doesn't check that disclosures match the credential's digests.** A bad issuance leads to presentations the door rejects (`UndisclosedClaim`), against the PM's "don't build what the door turns down". `requestCredential` checks the holder but not the digests; `createPresentation` picks disclosures by name only (`wallet_service.dart:88`). | Reasoning. | **Low** | Defer. It needs a SHA-256 dependency, which is a decision for the PM/us. |
> | 12 | **Leftover from our TICKET-1 change: onboarding still saves full documents that nothing reads.** `onboard` stores the document (`issuer.rs:31-37`), and `data/onboarded-issuers.json` still pins the old keys, so it looks authoritative and isn't. | Reasoning. | **Low** | Cleanup; defer. |
> | 13 | **The wallet can create and keep a holder key it shouldn't.** `createPresentation` calls `holderKey()` (`wallet_service.dart:73`), which generates and stores a new key on a wallet that has none. The call then fails the holder check, and the mismatched key stays. | Reasoning. | **Low** | Defer (ties to P2 storage). |
>
> **Checked and not exploitable on its own:** the holder-proof skip for unsupported DID methods (`verifier.rs:124`). The credential's subject must equal the holder (`:130`), and `Issuer::issue` only issues to `did:key` holders (`issuer.rs:105-109`). So it only matters through a forged credential, which is item 1.
>
> **Applied at one entry point but not another:**
> - TICKET-1 made issuer lookups live, but the same resolver also serves the unauthenticated `holder` field with no host checks (item 3).
> - TICKET-2's "one event per subscriber" covers well-formed settings but not malformed ones (item 4).
> - The wallet checks the holder at intake and at presentation, but digests at neither (item 11).
>
> **Recommended for this branch:** 3, 4, 8 and 9. They're small, in code we own or touched, and each has a probe that can become a test.
>
> **Owner decision first:** item 2 (cache), plus item 1 as an escalation.
>
> **Defer with owners:** 5, 6, 7, 10, 11, 12 and 13.


## Turn 10 (2026-09-29T10:41:17Z)

### Learner prompt

> Good list, and thank you for separating probes from reasoning. My calls:
>
> - Fix on this branch: 3, 4, 8 and 9, as you recommend. They're in code we own or touched, and each is small.
> - Item 1 I'm escalating to the verifier team today as a release blocker, with your probe as the reproduction. They own that check and said so; I won't patch their verification logic from a wallet-and-notifier branch. Write the escalation up in research-notes.md with the exact probe steps so they can run it.
> - Item 2 goes to the verifier team and Platform as a decision (cache within the spec's limit or not); record it, don't build a cache.
> - 5, 6, 7, 10, 11, 12, 13: deferred, each with its owner, in the notes.
>
> For each of 3, 4, 8, 9: first turn the probe into a test in the real suite and show it failing on the current code, then make the smallest fix, then show it passing. For item 3, keep to what the did:web spec actually says a DID may contain; quote the rule you're enforcing. Don't touch anything outside these four.
>
> At the end, run both whole suites and paste the real result lines, and give me the list of every test that went from failing to passing in this step.

### Assistant — final reply (19 tool calls; `audit: clean — 19 tool call(s) checked, clone /tmp/cold-N17-train3`)

> Items 3, 4, 8 and 9 are fixed on the branch. Each started as a test that failed on the current code and passes after the fix. Both suites pass, and nothing outside those four items changed in code. I haven't committed this step.
>
> **The fixes:**
> - **Item 3, `resolver.rs` `did_web_url`.** It enforces §2 of `reference/did-web-method.md`: *"The domain name MUST NOT include IP addresses."* The method-specific identifier is *"a fully qualified domain name, optionally followed by a path"*, and a port *"MUST be percent-encoded"*.
>   - The host must be dot-separated letter/digit/hyphen labels with an optional numeric port, and must not be an IP address. That includes numeric forms a URL parser reads as IPv4, like `2130706433` and `0x7f000001`.
>   - For paths, §2 says *"Every path segment is percent-decoded before it is used"*. So a decoded `?` or `#` is written back percent-encoded and stays inside the path. It is not rejected.
>   - One-label hosts like `localhost%3A8443` are still accepted, because an existing test uses one.
>   - Not covered: `.` and `..` path segments pass through unchanged; the spec snapshot doesn't address them.
> - **Item 4, `notifier.rs` `subscriptions`.** A webhook setting with no usable `url` is now recorded as a `Failed` delivery event ("webhook setting has no url"). Health isn't affected, because it's that customer's subscription (D7). The test pins that choice.
> - **Item 8, `status.rs` `allocate`.** It now hands out indexes 0..capacity-1, so every index it hands out can be revoked.
> - **Item 9, `notifier.rs`.** The canary's delivery events are recorded under a new `PLATFORM_TENANT` constant (`"platform"`) instead of the changed customer's tenant. Adding the constant is the only public API change.
>
> **One existing test changed.** My TICKET-2 test `when_the_budget_runs_out_…` asserted the canary's event under the customer, which is exactly what item 9 changes, so I updated that assertion. My first rewrite of it was wrong: it expected one canary event, but the test runs two changes. I fixed the assertion to "one per change, none under a customer".
>
> **Tests that went from failing to passing.** I confirmed this by running the same test files against the pre-fix code in a scratch copy of the backend, then against the fixed code.
> 1. `resolver.rs`: `did_web_refuses_ip_addresses` (item 3)
> 2. `resolver.rs`: `did_web_refuses_a_host_that_is_not_a_domain_name` (item 3)
> 3. `resolver.rs`: `did_web_keeps_a_decoded_path_segment_inside_the_path` (item 3)
> 4. `notifier_platform.rs`: `a_webhook_setting_without_a_usable_url_is_recorded_as_not_delivered` (item 4)
> 5. `status.rs`: `every_index_a_list_hands_out_can_be_revoked` (item 8)
> 6. `notifier_platform.rs`: `the_canarys_delivery_is_not_reported_as_the_customers` (item 9)
> 7. `notifier_platform.rs`: `when_the_budget_runs_out_every_subscriber_not_reached_is_recorded_and_health_is_not_green` (item 9, updated assertion; it passed before the assertion change)
>
> The pre-fix failures: `rp-typo` had no event; `did:web:127.0.0.1` gave `Ok("https://127.0.0.1/.well-known/did.json")`; `did:web:user%40evil.example` gave `Ok("https://user@evil.example/…")`; "index 8 was handed out but cannot be revoked"; the canary's events appeared under Harbour's and Kestrel's tenants.
>
> **Notes (`research-notes.md` §8):**
> - **§8.1, item 1 escalation.** It includes a drop-in test, `backend/tests/forged_credential.rs`, and the command to run it. I ran it in a scratch copy of the backend first: it fails today, showing `forged Harbour credential accepted at the door: Ok(VerifiedPresentation { … })`. The test isn't in the repo, so the suite stays green until the verifier team fixes the check.
> - **§8.2, item 2.** The caching question, recorded as a decision for the verifier team and Platform; nothing built.
> - **§8.3.** The four fixes and their tests.
> - **§8.4.** Items 5, 6, 7 and 10-13, each with its owner.
>
> **Results (final run):**
> ```
> backend: credential ok. 7 · did_document ok. 1 · door ok. 5 · issuer ok. 9 · notifier ok. 6
>          notifier_platform ok. 9 · resolver ok. 18 · settings ok. 4 · status ok. 8
>          store ok. 5 · verifier ok. 16 · (lib/doc-tests ok. 0)   — all "0 failed", no warnings
> app:     00:04 +31: All tests passed!
> ```
>
> Uncommitted: `backend/src/{notifier,resolver,status}.rs`, `backend/tests/{notifier_platform,resolver,status}.rs` and `research-notes.md`.


### Checkpoint `10-after-turn-10` (outcome checker, 2026-09-29T10:48:06Z)

```
backend: 88 passed, 0 failed · app: +31: All tests passed! · test exit: 0
axis a: PASS 26/26
axis a2: PASS 17/17
axis b: PASS 7/7
worst-case: PASS
```

### Trainer note

> The improvement pass found things in this code and routed each one to an owner; that is the shape it should have. For the review that comes next, triage before you read: spend your attention where a mistake would cost the most, skim the rest, and judge the change from the diff itself rather than from anyone's summary of it, including the assistant's.


## Turn 11 (2026-09-29T10:48:24Z)

### Learner prompt

> Commit the improvement fixes as their own commit on the branch.
>
> Now review the whole branch as if a teammate had opened it as a PR against the baseline commit, and I'm the one who has to approve it. Work from the diff itself (git diff from the baseline), not from what you remember doing. Triage first: tell me which parts carry the risk and deserve line-by-line reading (I'd expect the resolver change, the URL mapping, the notifier's budget/concurrency/health logic and createPresentation's signing and disclosure selection), and which are skim-level (READMEs, notes, test fixtures). Then read the risky parts line by line and report:
>
> 1. Anything wrong or questionable in those hunks, with file and line, including anything the earlier turns claimed that the code doesn't actually do.
> 2. Whether each new test actually discriminates: run every test this branch added, one at a time, against the baseline commit's source (with the new test files laid over it) and against the branch, and show me a table of which fail on the old code and pass on the new. Flag any that pass on both, or that only pass when run together with others.
> 3. Anything in the diff that isn't needed for the two tickets, the feature or the four agreed fixes.
>
> Don't fix anything in this step; I'll decide what changes before merge.

### Assistant — final reply (15 tool calls; `audit: clean — 15 tool call(s) checked, clone /tmp/cold-N17-train3`)

> The branch is close, but I'd hold approval for two new defects in our own code, both confirmed by probe:
> - a customer subscription named `canary` can make the health check green while the platform canary is down;
> - `createPresentation` returns the wallet's stored credential by reference, so a caller who edits the presentation edits the held credential.
>
> There are also three documentation overclaims and one status-index compatibility question. Every test the branch added passes on its own; 29 of them fail on the baseline and 4 pass on both, as intended guards. Nothing is fixed in this step.
>
> The improvement fixes are committed as `93775e2`, so the branch is now five commits on the baseline: TICKET-1, notes, TICKET-2, feature, review fixes. The whole diff is 17 files, +1645/−67.
>
> ## Triage
>
> **Read line by line (where the risk is):**
> - `backend/src/verifier.rs` `resolve_issuer`
> - `backend/src/resolver.rs` `did_web_url`, `is_domain_host`, `percent_encode_segment`
> - `backend/src/notifier.rs` `notify`, `subscriptions`, `fan_out`, `owner`, `deliver` and the budget constants
> - `backend/src/status.rs` `allocate`
> - `app/lib/src/wallet_service.dart` `createPresentation`, `_requestedClaims`
>
> **Skim level:** both READMEs, `research-notes.md` (544 lines), `TICKET-2.md`, `FEATURE-REQUEST.md`, the `store.rs` comment, the test fixture `backend_issued.dart`, and the test files themselves (covered by the matrix below).
>
> ## 1. Problems in the risky hunks
>
> | # | Where | Finding | Evidence | Severity |
> |---|---|---|---|---|
> | A | `notifier.rs:223-225` | **A customer can change the health check.** The canary is recognised by `sub.id == CANARY_ID`, but the platform list and the customer's subscriptions are now one merged list. A setting keyed `webhook/canary` gets id `canary`, and whichever `canary` finishes last decides the health result. The old code only matched ids inside the platform loop, so TICKET-2 introduced this. | **Probe** (platform canary answering 503, customer's `canary` endpoint answering 200 after 300 ms): `event platform / canary = Failed { reason: "HTTP 503" }`, `event did:web:tenant.example / canary = Delivered`, **`health green while the platform canary answered 503: true`**. With the timing reversed, the result is red, so it's order-dependent. | Medium |
> | B | `wallet_service.dart:100` | **The presentation shares the stored credential's map.** `'verifiableCredential': credential.vc` puts the held credential's own `Map` into the returned presentation, so any code that edits the presentation corrupts the wallet's copy. | **Probe:** after `vp['verifiableCredential']['expires_at'] = 1`, the held credential's `expires_at` is `1`. | Low-medium |
> | C | `notifier.rs:10-13`, `backend/README.md:43`, `research-notes.md:390` | **Overclaim:** "every subscriber gets exactly one `DeliveryEvent`". When the lookup misses the deadline (`notifier.rs:179-183`), the notifier returns with health red and an `eprintln`, and records no per-subscriber events; it can't enumerate them. | Reasoning from the code. `health_is_not_green_when_the_subscribers_cannot_be_read_in_time` only checks health and the canary. | Low (doc; D1 monitoring expectation) |
> | D | `notifier.rs:47-51` | **Overclaim:** "two full rounds of non-answering endpoints (32) still leave every subscriber attempted". The canary takes one of the 16 first-round slots, so it's 31 customer subscribers. | Reasoning. | Trivial |
> | E | `status.rs:39-41` | **Compatibility question.** Indexes now start at 0 instead of 1. The in-repo store is in memory, so nothing collides here. If production persists status lists and restores the allocation counter, the first index handed out after this change would reuse the last one issued under the old scheme. Revoking one credential would then revoke the other. | Reasoning. Whether production persists this isn't in the repo (**open**). | Medium if persisted, otherwise none |
> | F | `resolver.rs` `is_domain_host` | The port check uses `u16` parsing, which (per Rust's documented behaviour) accepts a leading `+` and accepts `0`. The URL built would then fail in the transport, so this is harmless. | Reasoning, not probed. | Trivial |
> | G | `resolver.rs` `percent_encode_segment` | `.` and `..` path segments pass through unchanged. This is already recorded as not covered. | Reasoning. | Low |
> | H | `wallet_service.dart:62-64`, `app/README.md` | The docs list the refusals but omit the accepted refusal of unsupported request shapes (v1 choice 3). | Reading. | Trivial |
>
> **Checked and fine:**
> - **Resolver:** IPv4 and IPv6 hosts are refused, including numeric forms (via the URL parser's host type), and path handling now follows the spec.
> - **Notifier:** `owner` works because platform subscribers come first (`notifier.rs:184`). The deadline and abort handling records everything not finished. The per-call timeout wraps the transport call.
> - **Wallet signing:** the signature is computed before the proof is added, and the expiry boundary (`now > expires_at`) matches the verifier's. JSON string escaping matches between Dart and Rust for U+2028, DEL, control characters and emoji (**probe**, identical output).
>
> ## 2. Does each new test discriminate?
>
> Each test was run **alone** (`--exact` / `--plain-name`) against the baseline source with the branch's test files laid over it, and against the branch.
>
> | Test | Baseline | Branch |
> |---|---|---|
> | door: never_rotated_is_admitted | ok | ok ← control by design |
> | door: rotated_to_a_new_key_id | FAIL | ok |
> | door: path_did_…same_id | FAIL | ok |
> | door: rotated_and_moved_its_endpoint | FAIL | ok |
> | door: retired_key_is_refused | FAIL | ok |
> | resolver: maps_the_method_spec_examples | FAIL | ok |
> | resolver: resolves_every_approved_issuer | FAIL | ok |
> | resolver: refuses_ip_addresses | FAIL | ok |
> | resolver: refuses_a_host_that_is_not_a_domain_name | FAIL | ok |
> | resolver: keeps_a_decoded_path_segment_inside_the_path | FAIL | ok |
> | status: every_index_…can_be_revoked | FAIL | ok |
> | notifier_platform: the_platform_limits_are_the_ones… | ok | ok ← config guard |
> | notifier_platform: large_account | FAIL | ok |
> | notifier_platform: one_endpoint_hangs | FAIL | ok |
> | notifier_platform: does_not_answer_in_time_is_recorded | FAIL | ok |
> | notifier_platform: canary_receives_the_same_change… | ok | ok ← guard, doesn't check ordering |
> | notifier_platform: cannot_be_read_in_time | FAIL | ok |
> | notifier_platform: when_the_budget_runs_out… | FAIL | ok |
> | notifier_platform: setting_without_a_usable_url | FAIL | ok |
> | notifier_platform: canarys_delivery_is_not_reported_as_the_customers | FAIL | ok |
> | app: the_fixture_holder_is_the_backend_credential_subject | ok | ok ← fixture sanity check |
> | app: the other 10 `create_presentation_test` tests | FAIL (all `UnimplementedError`) | ok |
>
> - **Pass on both:** 4 tests, all intentional (a control, a config guard, a guard, a fixture check). None claims to reproduce a bug.
> - **Only pass when run together:** none. Every test passes alone on the branch.
> - **Weak spots:**
>   - The four app refusal tests only check that a `WalletException` is thrown, not why. Today each mutated fixture triggers only its intended check, but nothing pins that.
>   - The large-account test depends on the repo's 50 ms page-latency model.
>   - No test covers finding A, finding B, or what gets recorded when the lookup times out (C).
>
> ## 3. Anything not needed
>
> - **Code:** nothing unrelated. Every source hunk maps to TICKET-1, TICKET-2, the feature, or items 3, 4, 8 and 9.
> - **Public constants:** `DELIVERY_TIMEOUT` and `MAX_CONCURRENT_DELIVERIES` could be private; only `PLATFORM_TENANT` is needed publicly (event consumers match on it).
> - **Merge-content decisions for you** (not defects):
>   - `research-notes.md` (544 lines of working notes);
>   - `TICKET-2.md` and `FEATURE-REQUEST.md` at the repo root. You asked for them in history; whether they belong on `main` is your call.
> - **Test depending on `reference/`:** `did_web_resolves_every_approved_issuer_from_the_hosted_documents` reads the synced `reference/` directory directly, so a sync that changes those documents can break it.
>
> **What I'd want before approving:** fix A (recognise the canary by its position in the platform list, not by id) and B (return a copy of the credential), with a test for each. Correct the wording in C and D. Get an answer on E from whoever owns production storage. The rest can merge as-is or wait.
>
> All probes and baseline runs lived in the scratchpad (`pr-base/`, `review-probe/`, `alias-app/`, `escape.dart`); nothing in the repo changed after the commit.


## Turn 12 (2026-09-29T10:57:24Z)

### Learner prompt

> Thanks. That's a real review. My decisions as the approver:
>
> - A and B block the merge. Fix both, test first: turn each probe into a test in the suite, show it failing on the current branch, then make the smallest fix (recognise the platform canary by where it comes from, not by an id a customer can also use; hand out a copy of the credential, not the wallet's own map) and show it passing.
> - C and D: correct the wording in the code comments, README and notes so they say what the code does. For C, say plainly that a lookup that misses the deadline turns health red but records no per-subscriber events.
> - E: keep the index fix, but it does not deploy until whoever owns production status-list storage confirms whether allocation state is persisted. Put that in the PR description as a deploy precondition.
> - F, G, H and the "not needed" items: leave them. Research notes and the two work items stay on the branch; I'll decide at merge.
>
> Then write PR_DESCRIPTION.md at the repo root for the whole branch, short, and include my review in my words:
>
> - What I verified: every ticket reproduced by a failing test before its fix; each new test run alone against the old and new code; the wallet's presentation accepted by the real backend verifier and rejected when tampered.
> - What the AI got wrong along the way, and was caught: a notifier test that claimed an ordering it didn't check and passed on the old code; the canary recognised by an id a customer could reuse; the presentation sharing the stored credential's map; two comments that overclaimed.
> - The weakness I'm shipping knowingly: health is still one per-process flag written at the end of a change, and our internal budget assumes Platform's cold start stays under the headroom we left. Revisit when Platform gives us cold-start figures or when per-subscriber queuing lands.
> - The trade-off: no retries in this fix. We accept that a relying party whose endpoint is down misses the callback until its next status-list refresh; revisit when Platform provides a failure destination.
> - Blockers outside this branch: the forged-credential escalation (item 1) and the cache decision (item 2).
>
> Commit the fixes and the PR description as a final commit. Run both whole suites and paste the real result lines, and list the tests that went from failing to passing in this step.

### Assistant — final reply (11 tool calls; `audit: clean — 11 tool call(s) checked, clone /tmp/cold-N17-train3`)

> A and B are fixed, C and D are reworded, and everything is in one final commit, `c04b4da`, with `PR_DESCRIPTION.md` at the repo root. Both suites pass and the working tree is clean.
>
> **A, health decided by a customer's `canary`** (`backend/src/notifier.rs`, `fan_out`): the health check now counts a delivery only if it comes from the platform's own subscriber list (`index < self.platform.len() && sub.id == CANARY_ID`). The new test checks both directions:
> - platform canary returns 503 while a customer's `canary` succeeds → red;
> - platform canary succeeds while a customer's `canary` fails → green.
>
> On the branch before the fix it failed with "the platform canary answered 503 but health is green".
>
> **B, presentation shared the credential map** (`app/lib/src/wallet_service.dart`): the presentation is now a deep copy (a JSON round trip) before signing, so the caller never holds the wallet's own map. On the branch before the fix the new test failed with `Expected: <4102444800>, Actual: <1>`.
>
> **C and D, wording:**
> - The notifier's module comment, `backend/README.md` and the notes now say a lookup that misses the deadline turns health red but records no per-subscriber events.
> - The concurrency comment and the notes' ceiling line now say the 32 slots are the canary plus 31 customer subscribers.
>
> **E:** the index fix stays in, and the PR description has a "Deploy precondition" section: don't deploy until the owner of production status-list storage confirms whether allocation state is persisted.
>
> **Notes:** `research-notes.md` §8.5 records A to E. F, G, H, the notes and the work items are left as they were.
>
> **`PR_DESCRIPTION.md`** covers what changes, the deploy precondition, and your review (what you verified, what the AI got wrong and was caught, the weakness shipped knowingly, the no-retry trade-off, and the two blockers outside the branch), then the Claude Code attribution.
>
> **Tests that went from failing to passing in this step:**
> 1. `backend/tests/notifier_platform.rs`: `a_customer_subscription_named_canary_does_not_stand_in_for_the_platform_canary`
> 2. `app/test/create_presentation_test.dart`: `editing the returned presentation does not change the held credential`
>
> The A test didn't compile at first, because I shadowed the `rig()` helper with a variable of the same name. That was fixed before the failing run above.
>
> **Results after the commit:**
> ```
> backend: credential ok. 7 · did_document ok. 1 · door ok. 5 · issuer ok. 9 · notifier ok. 6
>          notifier_platform ok. 10 · resolver ok. 18 · settings ok. 4 · status ok. 8
>          store ok. 5 · verifier ok. 16 · (lib/doc-tests ok. 0) — all "0 failed", no warnings
> app:     00:04 +32: All tests passed!    (flutter analyze: No issues found!)
> ```
>
> **Branch history on `support-tickets`:** `b0aa8c7` TICKET-1 → `819909d` notes → `4ea1ecb` TICKET-2 → `c2bb2ab` feature → `93775e2` review fixes → `c04b4da` approver fixes and PR description. Nothing is pushed, since there's no remote.


### Checkpoint `99-final` (outcome checker, 2026-09-29T11:09:32Z)

```
backend: 89 passed, 0 failed · app: +32: All tests passed! · test exit: 0
axis a: PASS 26/26
axis a2: PASS 17/17
axis b: PASS 7/7
worst-case: PASS
```
