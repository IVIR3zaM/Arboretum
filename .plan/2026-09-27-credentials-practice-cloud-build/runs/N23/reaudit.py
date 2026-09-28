#!/usr/bin/env python3
"""reaudit.py — re-run the N23 audit (scripts/cold/audit.py, --explain) over every recorded audit.txt
under runs/, each against the CLONE in its meta.env (`mkdir -p` if that dir is gone), and write
runs/N23/reaudit.txt.

Per run: the exit recorded in its audit.txt, the exit of the frozen ac9049b audit today
(tests/fixtures/audit_ac9049b.py, the verdict engine N23 keeps), the new exit, the surviving
VIOLATION lines and the cleared ones with the rule that cleared each. Then the C4 checks:
  - every run whose recorded audit was clean is clean;
  - N13/naive-void-1, N13/elicited-void-1, N11/try1/void-1, N14/cold-void-1 and N17
    superseded-try1 turn-02-void-1 / turn-07-void-1 still exit 1 and keep every finding ac9049b
    names on a command line, in a Read or in an interpreter-fed body (every finding but a (c)
    clearance of a cat/tee-to-file body);
  - N17 train/turn-09-void-1..3 are clean.
Exit 0 if every check holds, 1 otherwise.
"""
import contextlib
import datetime
import io
import os
import re
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
PLAN = os.path.normpath(os.path.join(HERE, "..", ".."))
RUNS = os.path.join(PLAN, "runs")
COLD = os.path.join(PLAN, "scripts", "cold")
sys.path.insert(0, os.path.join(COLD, "tests"))
import differential  # noqa: E402  (loads audit.py and the frozen ac9049b copy)

MUST_STAY_1 = ["N13/naive-void-1", "N13/elicited-void-1", "N11/try1/void-1", "N14/cold-void-1",
               "N17/superseded-try1/train/turn-02-void-1", "N17/superseded-try1/train/turn-07-void-1"]
MUST_CLEAN = ["N17/train/turn-09-void-1", "N17/train/turn-09-void-2", "N17/train/turn-09-void-3"]


def recorded_exit(text):
    m = re.search(r"^(?:audit )?exit: (\d+)", text, re.M)
    if m:
        return int(m.group(1))
    if re.search(r"^audit: clean", text, re.M):
        return 0
    return 1 if re.search(r"^audit: \d+ violation", text, re.M) else None


def main():
    out = [f"# N23 re-audit: scripts/cold/audit.py --explain over every recorded audit.txt under runs/,",
           f"# each against the CLONE in its meta.env. old = the exit in the run's audit.txt; ac9049b = the",
           f"# frozen pre-N23 audit today; new = the N23 audit. Cleared lines name their rule (a/b/c).",
           f"# {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}", ""]
    failures, summary = [], []
    for dirpath, _, files in sorted(os.walk(RUNS)):
        if "audit.txt" not in files or "transcript.jsonl" not in files:
            continue
        run = os.path.relpath(dirpath, RUNS)
        if run.startswith("N23"):
            continue
        clone = None
        for line in open(os.path.join(dirpath, "meta.env"), encoding="utf-8"):
            if line.startswith("CLONE="):
                clone = line.split("=", 1)[1].strip().strip("'\"")
        note = ""
        if not os.path.isdir(clone):
            os.makedirs(clone, exist_ok=True)
            note = f" (clone dir was gone: mkdir -p)"
        transcript = os.path.join(dirpath, "transcript.jsonl")
        old = recorded_exit(open(os.path.join(dirpath, "audit.txt"), encoding="utf-8").read())
        base = differential.run(differential.OLD, transcript, clone)
        new = differential.run(differential.NEW, transcript, clone, explain=True)
        errors = differential.identity(transcript, clone)[0]
        recs = differential.records(new[0])
        kept = [r for r in recs if r.startswith("VIOLATION ")]
        cleared = [r for r in recs if r.startswith("cleared (")]
        out.append(f"== runs/{run} (clone {clone}){note}")
        out.append(f"old exit {old} · ac9049b exit {base[2]} · new exit {new[2]} · "
                   f"{len(kept)} surviving, {len(cleared)} cleared")
        out += [f"  {r}" for r in kept + cleared]
        out.append("")
        summary.append(f"{run}: old {old}, ac9049b {base[2]}, new {new[2]}"
                       + (f", cleared {', '.join(sorted({c[9] for c in cleared}))}" if cleared else ""))
        for e in errors:
            failures.append(f"{run}: identity: {e}")
        if old == 0 and new[2] != 0:
            failures.append(f"{run}: was clean, new exit {new[2]}")
        if run in MUST_STAY_1:
            if new[2] != 1:
                failures.append(f"{run}: must still exit 1, got {new[2]}")
            if any(not c.startswith("cleared (c)") for c in cleared):
                failures.append(f"{run}: a command-line, Read or interpreter-body finding was cleared")
        if run in MUST_CLEAN and new[2] != 0:
            failures.append(f"{run}: must be clean, got {new[2]}")
    out.append("== summary")
    out += summary
    out.append("")
    out.append("== C4 checks: " + ("all hold" if not failures else f"{len(failures)} failure(s)"))
    out += failures
    text = "\n".join(out) + "\n"
    with open(os.path.join(HERE, "reaudit.txt"), "w", encoding="utf-8") as fh:
        fh.write(text)
    print("\n".join(summary))
    print("C4 checks: " + ("all hold" if not failures else "\n".join(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
