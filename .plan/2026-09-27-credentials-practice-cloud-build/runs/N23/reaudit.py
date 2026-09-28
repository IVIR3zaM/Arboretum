#!/usr/bin/env python3
"""reaudit.py — re-run the fixed scripts/cold/audit.py over every recorded audit.txt under runs/,
each against the CLONE in its meta.env, and write runs/N23/reaudit.txt.

For each run: the old exit and findings (from the recorded audit.txt), the new exit and findings,
and for every old finding the new audit no longer names, the D23 rule that cleared it. A rule is
credited when switching that rule (or that set of rules) off alone brings the finding back:
  (a) newline separator  -> audit.mark_newlines is the identity (with it go the quoting rewrites
                            that decide which newlines are separators: $'...', continuations, ...)
  (b) `//` URL authority -> audit.url_authority is always False
  (c) cat/tee-to-file    -> audit.writes_to_file is always False
The baseline is audit.py as it was before N23 (the last commit touching it that is not an N23
commit). With all three rules off, the audit must name every finding the baseline names (checked
per run), so nothing but (a), (b) and (c) clears a finding; findings only the new audit names (its
stricter quoting and subshell handling) are counted per run.
"""
import contextlib
import io
import itertools
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.path.normpath(os.path.join(HERE, "..", ".."))
RUNS = os.path.join(PLAN, "runs")
AUDIT_DIR = os.path.join(PLAN, "scripts", "cold")
sys.dont_write_bytecode = True  # no __pycache__ beside audit.py
sys.path.insert(0, AUDIT_DIR)
import audit  # noqa: E402

RULES = {
    "a": ("mark_newlines", lambda command: command),
    "b": ("url_authority", lambda delim, part: False),
    "c": ("writes_to_file", lambda line: False),
}
VIOLATION = re.compile(r"^VIOLATION .*$", re.M)
N20_COMMIT = "2341991"  # "N20: cold kit fix": the heredoc split


def run_variant(transcript, clone, off=()):
    saved = {}
    for r in off:
        name, stub = RULES[r]
        saved[name] = getattr(audit, name)
        setattr(audit, name, stub)
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            rc = audit.main(["audit.py", transcript, clone])
    finally:
        for name, fn in saved.items():
            setattr(audit, name, fn)
    return rc, buf.getvalue()


def old_exit(text):
    m = re.search(r"^(?:audit )?exit: (\d+)", text, re.M)
    if m:
        return int(m.group(1))
    if "audit: clean" in text:
        return 0
    return 1 if VIOLATION.search(text) else None


def base_commit():
    """The last commit that touched audit.py before N23."""
    log = subprocess.run(["git", "-C", AUDIT_DIR, "log", "--format=%H%x09%s", "--", "audit.py"],
                         capture_output=True, text=True, check=True).stdout
    for line in log.splitlines():
        sha, subject = line.split("\t", 1)
        if "N23" not in subject:
            return sha
    raise SystemExit("no pre-N23 commit of audit.py")


def main():
    base = base_commit()
    head_src = subprocess.run(["git", "-C", AUDIT_DIR, "show", f"{base}:./audit.py"],
                              capture_output=True, text=True, check=True).stdout
    tmpdir = tempfile.mkdtemp()
    head_audit = os.path.join(tmpdir, "audit_head.py")
    with open(head_audit, "w") as f:
        f.write(head_src)
    # the audit before N20's heredoc split, to credit findings N20 cleared before this node
    pre_n20_src = subprocess.run(["git", "-C", AUDIT_DIR, "show", f"{N20_COMMIT}^:./audit.py"],
                                 capture_output=True, text=True, check=True).stdout
    pre_n20_audit = os.path.join(tmpdir, "audit_pre_n20.py")
    with open(pre_n20_audit, "w") as f:
        f.write(pre_n20_src)

    audits = sorted(os.path.join(d, "audit.txt") for d, _, files in os.walk(RUNS)
                    if "audit.txt" in files and not d.startswith(HERE))
    out = ["# N23 re-audit: fixed scripts/cold/audit.py over every recorded audit.txt under runs/,",
           "# each against the CLONE in its meta.env. Rules: (a) newline separator, (b) `//` URL",
           "# authority, (c) cat/tee-to-file heredoc body. A cleared finding is credited to the rule",
           "# (or smallest set of rules) whose switch-off alone brings it back. Baseline: audit.py",
           f"# before N23 ({base[:7]}).", ""]
    summary = []
    for path in audits:
        run = os.path.relpath(os.path.dirname(path), PLAN)
        meta = os.path.join(os.path.dirname(path), "meta.env")
        clone = None
        for line in open(meta, encoding="utf-8"):
            if line.startswith("CLONE="):
                clone = line.split("=", 1)[1].strip().strip("'\"")
        transcript = os.path.join(os.path.dirname(path), "transcript.jsonl")
        out.append(f"== {run} (clone {clone})")
        if not os.path.isdir(clone):
            os.makedirs(clone)
            out.append(f"(clone dir {clone} was gone: mkdir -p)")
        old_text = open(path, encoding="utf-8").read()
        old_rc = old_exit(old_text)
        old_found = VIOLATION.findall(old_text)

        rc, text = run_variant(transcript, clone)
        new_found = VIOLATION.findall(text)
        head = subprocess.run([sys.executable, head_audit, transcript, clone],
                              capture_output=True, text=True)
        head_found = VIOLATION.findall(head.stdout)
        _, all_off = run_variant(transcript, clone, off=("a", "b", "c"))
        all_off_found = VIOLATION.findall(all_off)
        same_as_head = all(v in all_off_found for v in head_found)
        stricter = [v for v in new_found if v not in head_found]

        out.append(f"old exit: {old_rc} ({len(old_found)} finding(s))   new exit: {rc} "
                   f"({len(new_found)} finding(s))   all rules off names every baseline finding: "
                   f"{'yes' if same_as_head else 'NO'}   named by the new audit only: "
                   f"{len(stricter)}")
        for v in new_found:
            out.append(f"  new: {v}")
        cleared = [v for v in old_found if v not in new_found]
        kept = [v for v in old_found if v in new_found]
        if old_found:
            out.append(f"  old findings still named: {len(kept)} of {len(old_found)}")
        variants = {}
        for k in (1, 2, 3):
            for combo in itertools.combinations("abc", k):
                variants[combo] = VIOLATION.findall(run_variant(transcript, clone, off=combo)[1])
        unattributed = 0
        for v in cleared:
            why = None
            for k in (1, 2, 3):
                hits = [c for c in itertools.combinations("abc", k) if v in variants[c]]
                if hits:
                    why = " or ".join("+".join(f"({r})" for r in c) for c in hits)
                    break
            if why is None and v not in head_found:
                pre = subprocess.run([sys.executable, pre_n20_audit, transcript, clone],
                                     capture_output=True, text=True).stdout
                why = (f"N20's heredoc split ({N20_COMMIT}), before N23 — named by the audit "
                       f"before {N20_COMMIT}, not by the baseline; no N23 rule brings it back") \
                    if v in VIOLATION.findall(pre) else \
                    "an audit change before N20 — not named by the baseline; no N23 rule brings it back"
            if why is None:
                why = "UNATTRIBUTED"
                unattributed += 1
            out.append(f"  cleared by {why}: {v}")
        out.append("")
        summary.append((run, old_rc, rc, len(cleared), unattributed, same_as_head))

    out.append("== summary: run | old exit -> new exit | cleared findings | unattributed | "
               "all-off names every baseline finding")
    for run, o, n, c, u, s in summary:
        out.append(f"{run} | {o} -> {n} | {c} | {u} | {'yes' if s else 'NO'}")
    dest = os.path.join(HERE, "reaudit.txt")
    with open(dest, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("\n".join(out[-(len(summary) + 1):]))


if __name__ == "__main__":
    main()
