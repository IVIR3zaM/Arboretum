#!/usr/bin/env python3
"""plan.py — operate a resumable multi-agent execution graph.

Stdlib only. Safe for several agents running concurrently: every mutation of
state.json happens under an exclusive lockfile and is written atomically.

  plan.py init      [--root .plan]
  plan.py validate  [--root .plan]
  plan.py status    [--root .plan] [--json]
  plan.py next      [--root .plan] [--role worker]
  plan.py claim     ID --agent NAME [--lease-min 45]
  plan.py complete  ID --status done|awaiting_verification|blocked|revision_needed
                       [--summary TEXT] [--artifacts P1,P2] [--logs P1]
  plan.py reap      [--root .plan]
  plan.py approve   ID --by NAME [--note TEXT]
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

WORKER_ROLES = {"worker", "integrator", "surveyor", "digest"}
NO_MODEL_ROLES = {"router", "tool", "human_gate"}
TERMINAL = {"done", "skipped"}
CLAIMABLE = {"ready", "revision_needed"}

SUBDIRS = ["nodes", "handoffs", "digests", "logs", "approvals", "scripts"]


# ---------- utilities ----------

def now():
    return datetime.now(timezone.utc)


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    if not s:
        return None
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def die(msg, code=1):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def read_json(path, default=None):
    p = Path(path)
    if not p.exists():
        if default is not None:
            return default
        die(f"missing {path}")
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        die(f"{path} is not valid JSON: {e}")


def write_json_atomic(path, obj):
    p = Path(path)
    tmp = p.with_suffix(p.suffix + f".tmp{os.getpid()}")
    tmp.write_text(json.dumps(obj, indent=2) + "\n")
    os.replace(tmp, p)


class Lock:
    """Exclusive lockfile with a stale-lock timeout."""

    def __init__(self, root, timeout=30.0, stale=120.0):
        self.path = Path(root) / ".lock"
        self.timeout = timeout
        self.stale = stale
        self.fd = None

    def __enter__(self):
        deadline = time.time() + self.timeout
        while True:
            try:
                self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(self.fd, f"{os.getpid()} {iso(now())}\n".encode())
                return self
            except FileExistsError:
                try:
                    age = time.time() - self.path.stat().st_mtime
                    if age > self.stale:
                        self.path.unlink(missing_ok=True)
                        continue
                except FileNotFoundError:
                    continue
                if time.time() > deadline:
                    die("timed out waiting for .plan/.lock (remove it if stale)")
                time.sleep(0.2)

    def __exit__(self, *exc):
        if self.fd is not None:
            os.close(self.fd)
        self.path.unlink(missing_ok=True)


def log_event(root, **fields):
    rec = {"ts": iso(now())}
    rec.update(fields)
    with open(Path(root) / "ledger.jsonl", "a") as f:
        f.write(json.dumps(rec) + "\n")


def load(root):
    graph = read_json(Path(root) / "graph.json")
    state = read_json(Path(root) / "state.json", default={"nodes": {}})
    return graph, state


def nodes_by_id(graph):
    return {n["id"]: n for n in graph.get("nodes", [])}


# ---------- status derivation ----------

def refresh_ready(graph, state):
    """Promote pending nodes whose dependencies are all done."""
    by_id = nodes_by_id(graph)
    changed = []
    for nid, node in by_id.items():
        st = state["nodes"].setdefault(
            nid, {"status": "pending", "attempts": 0,
                  "lease_holder": None, "lease_expires_at": None})
        if st["status"] != "pending":
            continue
        deps = node.get("deps", [])
        if all(state["nodes"].get(d, {}).get("status") in TERMINAL for d in deps):
            st["status"] = "ready"
            changed.append(nid)
    return changed


def reap_expired(state):
    released = []
    for nid, st in state["nodes"].items():
        if st.get("status") != "in_progress":
            continue
        exp = parse_iso(st.get("lease_expires_at"))
        if exp and exp < now():
            st["status"] = "ready"
            st["lease_holder"] = None
            st["lease_expires_at"] = None
            released.append(nid)
    return released


# ---------- commands ----------

def cmd_init(args):
    root = Path(args.root)
    root.mkdir(parents=True, exist_ok=True)
    for d in SUBDIRS:
        (root / d).mkdir(exist_ok=True)
    if not (root / "graph.json").exists():
        write_json_atomic(root / "graph.json",
                          {"version": 1, "plan_root": str(root), "nodes": [], "edges": []})
    if not (root / "state.json").exists():
        write_json_atomic(root / "state.json", {"updated_at": iso(now()), "nodes": {}})
    (root / "ledger.jsonl").touch()
    gi = root / ".gitignore"
    if not gi.exists():
        gi.write_text("logs/\n.lock\n*.tmp*\n")
    log_event(root, event="plan_created")
    print(f"initialised {root}/")


def cmd_validate(args):
    root = Path(args.root)
    graph, state = load(root)
    by_id = nodes_by_id(graph)
    errs, warns = [], []

    if not by_id:
        errs.append("graph.json has no nodes")

    # verification contract V-numbers
    vfile = root / "VERIFICATION.md"
    vnums = set()
    if vfile.exists():
        vnums = set(re.findall(r"^###\s+(V\d+)", vfile.read_text(), re.M))
    else:
        warns.append("VERIFICATION.md missing — the contract was never confirmed")

    seen_verifiers = {}
    used_vnums = set()

    for nid, n in by_id.items():
        role = n.get("role")
        where = f"node {nid}"

        if not role:
            errs.append(f"{where}: no role")
        if role in NO_MODEL_ROLES and n.get("model_tier") not in (None, "none"):
            errs.append(f"{where}: role '{role}' is deterministic but has model_tier "
                        f"'{n.get('model_tier')}'")

        ctx = n.get("context", {})
        if role not in NO_MODEL_ROLES and not ctx.get("read"):
            errs.append(f"{where}: empty context.read — node is underspecified")

        for d in n.get("deps", []):
            if d not in by_id:
                errs.append(f"{where}: dep '{d}' does not exist")

        if not (root / "nodes").glob(f"{nid}-*.md"):
            pass
        if not list((root / "nodes").glob(f"{nid}*.md")):
            warns.append(f"{where}: no brief in nodes/")

        acc = n.get("acceptance", [])
        if role in WORKER_ROLES and not acc:
            errs.append(f"{where}: no acceptance criteria")
        for a in acc:
            v = a.get("verifier")
            if v:
                used_vnums.add(v)
                if vnums and v not in vnums:
                    errs.append(f"{where}: acceptance {a.get('id')} cites {v}, "
                                f"not defined in VERIFICATION.md")

        if role in WORKER_ROLES:
            vn = (n.get("verify") or {}).get("verifier_node")
            if not vn:
                errs.append(f"{where}: no verify.verifier_node")
            elif vn == nid:
                errs.append(f"{where}: verifies itself")
            elif vn not in by_id:
                errs.append(f"{where}: verifier_node '{vn}' does not exist")
            else:
                seen_verifiers.setdefault(vn, []).append(nid)

        b = n.get("budget", {})
        if role not in NO_MODEL_ROLES and not b.get("max_rounds"):
            warns.append(f"{where}: no budget.max_rounds (no stop rule)")

    # token thresholds
    mpath = root / "MODELS.yaml"
    thresholds = {}
    if mpath.exists():
        tier = None
        for line in mpath.read_text().splitlines():
            m = re.match(r"^  (\w+):\s*$", line)
            if m:
                tier = m.group(1)
            m2 = re.match(r"^\s+plan_threshold_tokens:\s*(\d+)", line)
            if m2 and tier:
                thresholds[tier] = int(m2.group(1))
    for nid, n in by_id.items():
        t = n.get("model_tier")
        est = (n.get("context") or {}).get("est_input_tokens")
        if t in thresholds and est and est > thresholds[t]:
            errs.append(f"node {nid}: est_input_tokens {est} exceeds tier '{t}' "
                        f"threshold {thresholds[t]} — split it or add a digest node")

    # cycles, ignoring declared revision edges
    rev = {(e["from"], e["to"]) for e in graph.get("edges", [])
           if e.get("type") == "revision"}
    adj = {nid: [d for d in n.get("deps", []) if (nid, d) not in rev]
           for nid, n in by_id.items()}
    colour = {}

    def visit(u, stack):
        colour[u] = 1
        for v in adj.get(u, []):
            if colour.get(v) == 1:
                errs.append(f"dependency cycle: {' -> '.join(stack + [u, v])}")
            elif colour.get(v, 0) == 0:
                visit(v, stack + [u])
        colour[u] = 2

    for nid in by_id:
        if colour.get(nid, 0) == 0:
            visit(nid, [])

    if vnums:
        for v in sorted(vnums - used_vnums):
            warns.append(f"{v} defined in VERIFICATION.md but no node's "
                         f"acceptance criteria cite it")

    for w in warns:
        print(f"warn:  {w}")
    for e in errs:
        print(f"ERROR: {e}")
    print(f"\n{len(by_id)} nodes · {len(errs)} errors · {len(warns)} warnings")
    sys.exit(1 if errs else 0)


def cmd_status(args):
    root = Path(args.root)
    graph, state = load(root)
    with Lock(root):
        reap_expired(state)
        refresh_ready(graph, state)
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)
    by_id = nodes_by_id(graph)

    if args.json:
        print(json.dumps(state, indent=2))
        return

    counts = {}
    for st in state["nodes"].values():
        counts[st["status"]] = counts.get(st["status"], 0) + 1
    order = ["done", "in_progress", "awaiting_verification", "awaiting_adversary",
             "awaiting_approval", "revision_needed", "ready", "pending",
             "blocked", "skipped"]
    total = len(state["nodes"])
    print(f"{total} nodes  " + "  ".join(
        f"{k}:{counts[k]}" for k in order if k in counts))

    ready = [n for n, s in state["nodes"].items() if s["status"] in CLAIMABLE]
    print(f"parallel width available now: {len(ready)}")

    interesting = [s for s in ("in_progress", "blocked", "awaiting_approval",
                               "awaiting_verification", "revision_needed")
                   if s in counts]
    for s in interesting:
        print(f"\n{s}:")
        for nid, st in sorted(state["nodes"].items()):
            if st["status"] == s:
                n = by_id.get(nid, {})
                extra = f"  [{st['lease_holder']}]" if st.get("lease_holder") else ""
                print(f"  {nid}  {n.get('title','?')}{extra}")


def cmd_next(args):
    root = Path(args.root)
    graph, state = load(root)
    by_id = nodes_by_id(graph)
    with Lock(root):
        reap_expired(state)
        refresh_ready(graph, state)
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)

    cands = []
    for nid, st in state["nodes"].items():
        if st["status"] not in CLAIMABLE:
            continue
        n = by_id.get(nid)
        if not n:
            continue
        if args.role and n.get("role") != args.role:
            continue
        cands.append(n)
    if not cands:
        print(json.dumps({"node": None, "reason": "nothing claimable"}))
        return
    # revision_needed first, then lowest id
    cands.sort(key=lambda n: (
        0 if state["nodes"][n["id"]]["status"] == "revision_needed" else 1, n["id"]))
    n = cands[0]
    brief = sorted((root / "nodes").glob(f"{n['id']}*.md"))
    print(json.dumps({
        "node": n["id"], "title": n.get("title"), "role": n.get("role"),
        "model_tier": n.get("model_tier"),
        "brief": str(brief[0]) if brief else None,
        "read": (n.get("context") or {}).get("read", []),
        "dep_handoffs": [str(root / "handoffs" / f"{d}.json") for d in n.get("deps", [])],
        "attempts": state["nodes"][n["id"]]["attempts"],
        "max_rounds": (n.get("budget") or {}).get("max_rounds"),
    }, indent=2))


def cmd_claim(args):
    root = Path(args.root)
    graph, state = load(root)
    by_id = nodes_by_id(graph)
    if args.id not in by_id:
        die(f"no node '{args.id}'")
    with Lock(root):
        reap_expired(state)
        st = state["nodes"].setdefault(
            args.id, {"status": "pending", "attempts": 0,
                      "lease_holder": None, "lease_expires_at": None})
        if st["status"] not in CLAIMABLE:
            die(f"node {args.id} is '{st['status']}', not claimable")
        maxr = (by_id[args.id].get("budget") or {}).get("max_rounds")
        if maxr and st["attempts"] >= maxr:
            st["status"] = "blocked"
            write_json_atomic(root / "state.json", state)
            log_event(root, node=args.id, event="blocked", reason="max_rounds exhausted")
            die(f"node {args.id} has exhausted max_rounds ({maxr}) — now blocked")
        st["status"] = "in_progress"
        st["attempts"] += 1
        st["lease_holder"] = args.agent
        st["lease_expires_at"] = iso(now() + timedelta(minutes=args.lease_min))
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)
    log_event(root, node=args.id, event="claimed", agent=args.agent,
              attempt=st["attempts"])
    print(json.dumps({"node": args.id, "attempt": st["attempts"],
                      "lease_expires_at": st["lease_expires_at"]}, indent=2))


def cmd_complete(args):
    root = Path(args.root)
    graph, state = load(root)
    by_id = nodes_by_id(graph)
    if args.id not in by_id:
        die(f"no node '{args.id}'")
    handoff = {
        "node_id": args.id,
        "status": args.status,
        "artifact_paths": [p for p in (args.artifacts or "").split(",") if p],
        "summary": args.summary or "",
        "open_questions": [q for q in (args.open_questions or "").split("|") if q],
        "log_paths": [p for p in (args.logs or "").split(",") if p],
    }
    write_json_atomic(root / "handoffs" / f"{args.id}.json", handoff)
    with Lock(root):
        st = state["nodes"][args.id]
        st["status"] = args.status
        st["lease_holder"] = None
        st["lease_expires_at"] = None
        refresh_ready(graph, state)
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)
    log_event(root, node=args.id, event="handoff", status=args.status)
    print(f"{args.id} -> {args.status}")


def cmd_reap(args):
    root = Path(args.root)
    graph, state = load(root)
    with Lock(root):
        released = reap_expired(state)
        refresh_ready(graph, state)
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)
    for nid in released:
        log_event(root, node=nid, event="lease_expired")
    print(f"released {len(released)}: {', '.join(released) if released else '-'}")


def cmd_approve(args):
    root = Path(args.root)
    graph, state = load(root)
    (root / "approvals" / f"{args.id}.txt").write_text(
        f"{iso(now())}\nby: {args.by}\n{args.note or ''}\n")
    with Lock(root):
        state["nodes"][args.id]["status"] = "done"
        refresh_ready(graph, state)
        state["updated_at"] = iso(now())
        write_json_atomic(root / "state.json", state)
    log_event(root, node=args.id, event="approved", by=args.by)
    print(f"{args.id} approved by {args.by}")


def main():
    # --root accepted on either side of the subcommand
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", default=".plan")

    p = argparse.ArgumentParser(prog="plan.py", parents=[common])
    sub = p.add_subparsers(dest="cmd", required=True)

    def add(name):
        return sub.add_parser(name, parents=[common])

    add("init")
    add("validate")
    s = add("status"); s.add_argument("--json", action="store_true")
    s = add("next"); s.add_argument("--role")
    s = add("claim")
    s.add_argument("id"); s.add_argument("--agent", required=True)
    s.add_argument("--lease-min", type=int, default=45)
    s = add("complete")
    s.add_argument("id")
    s.add_argument("--status", required=True,
                   choices=["done", "awaiting_verification", "awaiting_adversary",
                            "awaiting_approval", "blocked", "revision_needed"])
    s.add_argument("--summary"); s.add_argument("--artifacts")
    s.add_argument("--logs"); s.add_argument("--open-questions")
    add("reap")
    s = add("approve")
    s.add_argument("id"); s.add_argument("--by", required=True); s.add_argument("--note")

    args = p.parse_args()
    {"init": cmd_init, "validate": cmd_validate, "status": cmd_status,
     "next": cmd_next, "claim": cmd_claim, "complete": cmd_complete,
     "reap": cmd_reap, "approve": cmd_approve}[args.cmd](args)


if __name__ == "__main__":
    main()
