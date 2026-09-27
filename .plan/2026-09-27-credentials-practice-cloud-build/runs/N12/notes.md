# N12 — axis (a2) grader + ticket-2.patch

Paths relative to `practices/credentials/`.

- Grader: `_solutions/grader/src/a2.rs`, bin `grade-a2` (Cargo.toml). New direct deps `tokio =1.53.1`
  (`rt, time, test-util`) and `url =2.5.8`, both already in the backend's lock; the grader's
  Cargo.lock only gained the two dependency names (`cargo update --offline --workspace`).
- Wrapper: `_solutions/grade.d/a2.sh` (same shape as a.sh; last line `axis a2: PASS|FAIL n/m`).
- 17 cases, worst-case: D1-D4 delivered within budget; C1/C3 canary healthy (all healthy);
  O2/O4 hanging endpoint's timeout reaches the sink (event naming that subscription id or url,
  outcome not `Delivered`); K1-K4 canary healthy ⇒ every healthy subscriber delivered;
  R1-R4 no call to a reserved name; P1 a healthy change then a tenant whose subscriptions cannot
  be read within the budget even through the index (24 000 subscriptions) — the canary must turn red.
- C4: budget = `reference/infra/webhook-config.yaml` `function.timeout_seconds`, imposed outside
  the notifier; reserved names = the table in `reference/infra/reserved-domains.md`. The transport
  and sink are grader-owned: reserved names are answered in-process (200, recorded as a violation),
  other unregistered URLs are platform endpoints answered 200. Evidence: `c4-reference-and-network.txt`
  (PASS inside `unshare -rn`; editing either reference file moves the result).
- ticket-2.patch touches only `backend/src/notifier.rs`: A1 fan-out-timeout event + per-call
  timeout reported as `Failed`; A2 `CALL_TIMEOUT` 5 s + concurrent `join_all` (std-only helper,
  no new crate); A3 `query_kind`; A4 loopback `CANARY_URL`, canary dispatched after the lookup with
  the tenant's subscribers, `canary_ok` reset per change. Visible suite stays green (68).
- Split: `axis-A{1..4}.patch` are each axis alone against planted + ticket-1. A1's per-call arm
  needs A2's per-call timeout, so `axis-A1.patch` holds only the fan-out-timeout event and
  `axis-A2.patch` carries a silent `Err(_) => return false` arm. `all-but-A{1..4}.patch` are extra
  evidence that every axis is necessary (all FAIL).

| Tree (on planted + ticket-1) | axis a2 |
|---|---|
| none (`c1-t1-only.txt`) | FAIL 4/17 |
| ticket-2 (`c1-t1-t2.txt`) | PASS 17/17 (axis a PASS 21/21) |
| A1 / A2 / A3 / A4 alone (`c2-axis-*.txt`) | FAIL 4 / 6 / 6 / 11 of 17 |
| all but A1 / A2 / A3 / A4 (`c2-all-but-*.txt`) | FAIL 15 / 13 / 13 / 12 of 17 |

Axis b is FAIL 0/7 in both C1 runs: the phase-3 feature is not implemented on these trees.
