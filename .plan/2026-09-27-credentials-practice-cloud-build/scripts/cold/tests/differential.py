#!/usr/bin/env python3
"""differential.py — the N23 audit against the frozen ac9049b audit, mechanically.

Identity (every transcript in the corpus):
  - with COLD_AUDIT_RULES=none the new audit prints byte for byte what ac9049b prints (stdout,
    stderr, exit code);
  - with the rules on, every VIOLATION line it prints is one ac9049b printed, in ac9049b's order;
    each line it drops is printed by --explain as `cleared (<rule>): <that line>`, and the survivors
    plus the cleared lines are exactly ac9049b's lines; exit 1 iff a line survives.
Corpus: --runs DIR (every recorded audit.txt dir under it: its transcript.jsonl against the CLONE in
its meta.env, `mkdir -p` if that dir is gone), --cases DIR (every *.jsonl in it, against --clone),
--fixtures DIR (every *.jsonl in it with @@CLONE@@ replaced by --clone).

Real-bash fuzz (--fuzz N --seed S): N generated transcripts of one to three Bash calls — separators,
every quoting form, ( ), { }, $( ), backticks, case/if/for/while, functions, comments, line
continuations, heredocs of each kind, assignments, cds to existing, missing, symlinked and `..` dirs —
plus every repro of run.sh's must-exit-1 cases. Each transcript runs in its own scratch tree:
  T/, T/p/, T/p/q/, T/p/q/r/, T/p/q/r/side/ and HOME=T/home are outside the clone, each holding `x`
  (content `OUTSIDE-MARK <that dir>`) and a file named OUTSIDE-MARK-name-<dir tag> (p/q -> p.q, T ->
  root), so every outside location has its own marker; the clone T/p/q/r/clone holds x, src/,
  src/sub/, sub/, a/b/c/d/, app/, backend/, https:/h.example/ (also in src/), and lnk -> T/p/q/r/side.
Each call is one bash process started in the carried cwd (the Bash tool's model: only the cwd
persists), reset to the clone if it ended outside. After the run both audits read the transcript
and the tree. The escape evidence E of a run is a set of items, tree-relative: `read <dir>` (the
content marker of <dir>'s x), `name <tag>` (the name marker of a dir, i.e. a listing or glob of it)
found in the outputs or in a file left in the clone, `host /etc/passwd` (the host's first line), and
`changed <path>` (an outside path created, changed or removed). A candidate is a transcript where
ac9049b exits 1, the new audit exits 0 and E is non-empty; it reruns in a fresh tree with every
cleared finding's token (or part) neutralized. A regression (C3, location by location) is an item of
E(original) missing from E(neutralized), or a cleared token that is not in its call. A candidate
with no missing item is an escape ac9049b never flagged (blind): counted and shown (--show-blind),
not failed.
--cases also replays every run.sh case's Bash calls in real bash the same way (the run.sh clone path
becomes the tree's clone, the real HOME the tree's HOME); --gaps NAMES checks that each named case
(run.sh's expect_gap cases, the ac9049b gaps under I2) exits 0 on both audits and escapes in bash
(E non-empty). The generator never makes a
directory (so rule (a)'s accepted residual, a cd target the call itself creates, cannot occur), and
it runs a file the transcript wrote only through bash, sh, source/. or ./file (the runners rule (c)
checks; D23 leaves other ways to run written content unaudited, as with the Write tool).

Exit 0: no identity error and no regression. Exit 1: otherwise (each printed).
"""
import argparse
import contextlib
import importlib.util
import io
import json
import multiprocessing
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


OLD = load("audit_ac9049b", os.path.join(HERE, "fixtures", "audit_ac9049b.py"))
NEW = load("audit_n23", os.path.join(HERE, "..", "audit.py"))
CLEARED = re.compile(r"^cleared \(([abc])\): (VIOLATION .*)$", re.S)
RECORD_START = re.compile(r"^(?:VIOLATION |cleared \([abc]\): VIOLATION |audit: )")


def records(text):
    """An audit's stdout as records: a VIOLATION line (with any continuation lines a newline in a
    token made), a cleared line, or the summary line."""
    out = []
    for ln in text.split("\n"):
        if RECORD_START.match(ln) or not out:
            out.append(ln)
        else:
            out[-1] += "\n" + ln
    return out


def run(mod, transcript, clone, rules=None, explain=False):
    saved = os.environ.get("COLD_AUDIT_RULES")
    if rules is None:
        os.environ.pop("COLD_AUDIT_RULES", None)
    else:
        os.environ["COLD_AUDIT_RULES"] = rules
    out, err = io.StringIO(), io.StringIO()
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = mod.main(["audit.py"] + (["--explain"] if explain else []) + [transcript, clone])
    finally:
        if saved is None:
            os.environ.pop("COLD_AUDIT_RULES", None)
        else:
            os.environ["COLD_AUDIT_RULES"] = saved
    return out.getvalue(), err.getvalue(), rc


def identity(transcript, clone):
    """Return (errors, old_rc, new_rc, {rule: cleared count})."""
    errors = []
    old = run(OLD, transcript, clone)
    none = run(NEW, transcript, clone, rules="none")
    if none != old:
        errors.append("COLD_AUDIT_RULES=none output differs from ac9049b")
    on = run(NEW, transcript, clone)
    exp = run(NEW, transcript, clone, explain=True)
    old_lines = [ln for ln in records(old[0]) if ln.startswith("VIOLATION ")]
    merged, kept, cleared = [], [], {}
    for ln in records(exp[0]):
        m = CLEARED.match(ln)
        if m:
            merged.append(m.group(2))
            cleared[m.group(1)] = cleared.get(m.group(1), 0) + 1
        elif ln.startswith("VIOLATION "):
            merged.append(ln)
            kept.append(ln)
    on_lines = [ln for ln in records(on[0]) if ln.startswith("VIOLATION ")]
    if merged != old_lines:
        errors.append("--explain lines (kept + cleared) are not ac9049b's VIOLATION lines")
    if on_lines != kept:
        errors.append("the printed VIOLATION lines are not the --explain survivors")
    if on[2] != (1 if kept else 0) or old[2] not in (0, 1) and on[2] != old[2]:
        errors.append(f"exit {on[2]} with {len(kept)} surviving line(s)")
    rest = [ln for ln in records(exp[0]) if not CLEARED.match(ln)]
    if rest != records(on[0]) or exp[1] != on[1]:
        errors.append("--explain changes more than the cleared lines")
    return errors, old[2], on[2], cleared


# ---------------------------------------------------------------------------- corpus

def corpus(args, tmp):
    items = []   # (label, transcript, clone)
    if args.runs:
        for dirpath, _, files in sorted(os.walk(args.runs)):
            if "audit.txt" not in files or "transcript.jsonl" not in files:
                continue
            clone = None
            meta = os.path.join(dirpath, "meta.env")
            if os.path.exists(meta):
                for line in open(meta, encoding="utf-8"):
                    if line.startswith("CLONE="):
                        clone = line.split("=", 1)[1].strip().strip("'\"")
            if not clone:
                continue
            os.makedirs(clone, exist_ok=True)
            items.append((os.path.relpath(dirpath, args.runs), os.path.join(dirpath, "transcript.jsonl"), clone))
    if args.cases:
        for f in sorted(os.listdir(args.cases)):
            if f.endswith(".jsonl"):
                items.append(("case " + f[:-6], os.path.join(args.cases, f), args.clone))
    if args.fixtures:
        for f in sorted(os.listdir(args.fixtures)):
            if f.endswith(".jsonl"):
                text = open(os.path.join(args.fixtures, f), encoding="utf-8").read()
                path = os.path.join(tmp, "fixture-" + f)
                with open(path, "w", encoding="utf-8") as fh:
                    fh.write(text.replace("@@CLONE@@", args.clone))
                items.append(("fixture " + f[:-6], path, args.clone))
    return items


# ---------------------------------------------------------------------------- fuzz

MARK = "OUTSIDE-MARK"
try:
    with open("/etc/passwd", encoding="utf-8", errors="replace") as _fh:
        HOST_MARK = _fh.readline().strip() or None
except OSError:
    HOST_MARK = None

# run.sh's must-exit-1 repros (and the replan's), as Bash calls from the clone
REPROS = [
    ["cd .. && ls"], ["cat ../../secrets.txt"], ["ls src && cat /etc/hostname"],
    ["echo x\ncd ..\nls"], ["S=/x\ncat $S/../../etc/passwd"], ["X=1\ncd backend\ncat ../../x"],
    ['echo "a\ncd sub" && cat ../x'], ["echo a \\\ncd sub && cat ../x"],
    ["cat /etc/../etc/passwd"], ["a=(\nx\ncd sub\n)\ncat ../y"], ["cat a://../../etc/passwd"],
    ["cat //../etc/passwd"], ["echo $'a\\'\ncd sub\n' ; cat ../x"], ["X=$'\\'\ncd sub\n'; cat ../x"],
    ["echo $'a\\\\'\ncd sub\ncat ../x"], ['echo $"a\ncd sub" && cat ../x'],
    ['echo "a\\\ncd sub" && cat ../x'], ["(echo a)#it's\n'\ncd sub\n'; cat ../x"],
    ["echo a\\\n#'\ncd sub\n'; cat ../x"], ['echo "$(case x in a) echo "\ncd sub\n";; esac)"; cat ../x'],
    ["(case x in a) echo x\ncd sub\n;; esac); cat ../x"], ["echo ${x:-'\ncd sub\n'}; cat ../x"],
    ["echo \"${x:-'\"'}\"; echo '\ncd sub\n'; cat ../x"], ["echo ${x:-a\ncd sub\n}; cat ../x"],
    ["cat > t.txt <<'EOF'\ncd sub\nEOF\ncat ../x"],
    ["X=1\ncd nonexist\ncat ../x"], ["X=1\ncd src; cd nonexist; cat ../../x"],
    ["cd nonexist; true", "X=1\ncd src && cat ../../x"], ["if false\nthen\ncd src\nfi\ncat ../x"],
    ["f() {\ncd src\n}\ncat ../x"],
    ["cd a/b/c/d", "echo '(' ; cd ../../.. ; echo ')' ; cat ../../x"],
    ["cd a/b/c/d", "(cd ../../.. && echo ')' && cat ../../x)"],
    ["cd a/b/c/d", "(cd ../../.. && echo $')' && cat ../../x)"],
    ["cd a/b/c/d", "(cd ../../.. && echo `echo )` && cat ../../x)"],
    ["cd a/b/c/d", "(cd ../../.. && echo ${x:-)} && cat ../../x)"],
    ["cd a/b/c/d", "(cd ../../.. && case y in y) cat ../../x;; esac)"],
    ["cd a/b/c/d", "echo $(cd ../../.. && case y in y) cat ../../x;; esac)"],
    ['X=1\ncd src ";"\ncat ../x'], ["X=1\ncd src \\;\ncat ../x"],
    ["X=1\ncd src\nfalse && cd sub\ncat ../../x"], ["X=1\ncd src\ncd sub | true\ncat ../../x"],
    ["X=1\ncd src && cat x & cat ../x"], ["X=1\ncd src\nexit\ncd sub", "cat ../../x"],
    ["set -e\nX=1\ncd src\nfalse\ncd sub", "cat ../../x"], ["X=1\ncd src\nls ;;\ncd sub", "cat ../../x"],
    ["X=1\ncd src\nC=cd\n$C ..\ncat ../x"], ["X=1\nCDPATH=..\ncd r\ncat ../x"],
    ["X=1\nIFS=/\nS=src/sub\ncd $S\ncat ../../x"], ["X=1\ncd src\ntrap 'cd ..' DEBUG\ncat ../x"],
    ["X=1\ncd lnk && cat ../x"], ["X=1\ncd src && cat ../lnk/../x"],
    ["curl -s file://localhost/../../etc/passwd"], ["cat https://h.example/../../../x"],
    ["cat > f <<'A'B\nx\nAB\ncat /etc/passwd\nA"],
    ["cat() { python3 - ; }\ncat > f.txt <<'EOF'\nprint(open(\"/etc/passwd\").read())\nEOF"],
    ["hash -p /usr/bin/python3 cat\ncat > f.txt <<'EOF'\nprint(open(\"/etc/passwd\").read())\nEOF"],
    ["cat > f.txt <<EOF\n$(echo \")\" ; cat /etc/passwd)\nEOF"],
    ["cat > $HOME/x.txt <<'EOF'\nhi\nEOF"], ["cat > ../../x.txt <<'EOF'\nhi\nEOF"],
    ["cat > x.txt <<EOF\n$(cat /etc/passwd)\nEOF"], ["cat <<'EOF' | sh\ncat ~/x\nEOF"],
    ["python3 - <<'EOF'\nprint(open(\"/etc/passwd\").read())\nEOF"],
    ["python3 - <<'EOF'\nprint(open(\"../../x\").read())\nEOF"],
    ["X=1\npushd src\npushd sub\npushd +1 && cat ../../x"], ["X=1\ncd src\nenv -C .. cat ../x"],
    ["X=1\nln -s lnk up\ncd up && cat ../x && cd .. && rm up"],
    ["cat > s.sh <<'EOF'\ncat ../x\nEOF\nbash s.sh"], ["cat > s.sh <<'EOF'\ncat ../x\nEOF", "sh s.sh"],
    ["tee s.sh <<'EOF' >/dev/null\ncat ../x\nEOF\nchmod +x s.sh && ./s.sh"],
    ["cat > s.py <<'EOF'\nprint(open('../x').read())\nEOF\npython3 s.py"],
]

# path and dir templates: {C} the clone, {R} the tree root (outside), {H} HOME
READ_PATHS = [
    "x", "../x", "../../x", "../../../x", "../../../../x", "src/x", "../src/x", "src/../../x",
    "sub/../x", "./x", '"../x"', "'../x'", "$'../x'", "\\.\\./x", "../r/x", "../../q/r/x",
    "a/b/c/d/../../../../../x", "src/sub/../../../x", "$S/x", "$S/../x", "$S/../../x", "${S}/../x",
    "~/x", "$HOME/x", "{C}/x", "{C}/../x", "{R}/x", "{R}/p/x", "{R}/p/q/r/x", "{H}/x",
    "https://h.example/x", "https://h.example/../x", "https://h.example/../../x",
    "https://h.example/../../../x", "https:/h.example/../../x", "lnk/x", "lnk/../x",
    "src/lnk/../x", "../lnk/../x", "a/../../x", "..//x", ".././x", "src/./../../x",
    "$D/x", "../$X/x",
]
DIRS = [
    "src", "sub", "src/sub", "a/b/c/d", "a/b", "a", "..", "../..", "../../..", "nonexist",
    "src/nope", "{C}/src", "{C}/nonexist", "{C}", "{C}/a/b", "{R}/p", "{R}/p/q/r", "~", "/",
    "lnk", "$S", "$S/..", "$D", "https:/h.example", "-", "./src", "src/..", "src/../..", '"src"',
    "'..'", "{C}/src/sub", "{C}/app", "app", "backend", "r", "side",
]
VALUES = ["{C}/src", "{C}", "{C}/nonexist", "{R}/p", "/x", "src", "..", "../..", "sub", "{C}/a/b/c/d",
          "a/b", "nonexist", "{R}/p/q/r/side", "cd", "1"]
QUOTED = ["(", ")", ";", "\ncd sub\n", "\ncd ..\n", ";cd ..;", "}", "{", "&&", "|", "#", " ) ",
          "$(", "\n)\n", "<<EOF", "x\ny", "../x"]


def fill(t, r, ctx):
    return (t.replace("{C}", ctx["C"]).replace("{R}", ctx["R"]).replace("{H}", ctx["H"]))


def gen_path(r, ctx):
    return fill(r.choice(READ_PATHS), r, ctx)


def gen_dir(r, ctx):
    return fill(r.choice(DIRS), r, ctx)


def gen_quote_noise(r):
    q = r.choice(QUOTED)
    form = r.randrange(7)
    if form == 0 and "'" not in q:
        return f"echo '{q}'"
    if form == 1:
        return 'echo "' + q.replace('"', '\\"').replace("$", "\\$").replace("`", "\\`") + '"'
    if form == 2:
        return "echo $'" + q.replace("\n", "\\n") + "\\''"
    if form == 3:
        return "X=$'" + q + "'"
    if form == 4 and '"' not in q:
        return 'echo $"' + q.replace("$", "\\$") + '"'
    if form == 5:
        return "echo a # " + q.replace("\n", " ")
    return "# " + q.replace("\n", " ")


def gen_primitive(r, ctx):
    k = r.randrange(26)
    p, d = gen_path(r, ctx), gen_dir(r, ctx)
    if k <= 4:
        return r.choice([f"cat {p}", f"cat {p} 2>/dev/null", f"head -1 {p}", f"cat < {p}",
                         f"cat -- {p}", f"grep -h . {p}", f"cp {p} got.txt"])
    if k <= 6:
        return r.choice([f"ls {d}", f"ls {d} 2>/dev/null", "ls", "ls ."])
    if k <= 11:
        return r.choice([f"cd {d}", f"cd {d}", f"cd {d}", f'cd "{d}"', f"pushd {d} >/dev/null",
                         f"pushd {d}", "popd", "cd", "cd -", f"cd -P {d}", f"builtin cd {d}",
                         f"command cd {d}", f"CDPATH=.. cd {d}", f"C=cd; $C {d}", f"c[d] {d}",
                         f"cd {d} ';'", f"cd {d} \\;", f"X=1 cd {d}", f"cd {d} >/dev/null"])
    if k <= 14:
        v = fill(r.choice(VALUES), r, ctx)
        return r.choice([f"S={v}", f"D={v}", f"X={v}", "X=1", f"export S={v}", f"S={v}; D={v}",
                         f"S='{v}'", "IFS=/", "CDPATH=..", f"read S <<< {v}", f"printf -v S %s {v}"])
    if k <= 16:
        return r.choice(["true", "false", "exit", "set -e", "trap 'cd ..' DEBUG", "echo ok",
                         "ls ;;", "hash -p /usr/bin/python3 cat", "cat() { python3 - ; }",
                         "wait", "return", "shopt -s expand_aliases"])
    if k <= 18:
        f = r.choice(["t.txt", "../t.txt", "$HOME/t.txt", "src/t.txt", "{R}/t.txt", "lnk/t.txt"])
        return r.choice([f"echo hi > {fill(f, r, ctx)}", f"echo hi >> {fill(f, r, ctx)}"])
    if k == 19 and shutil.which("curl"):
        return f"curl -s file://localhost/../../..{ctx['R']}/p/x"
    if k == 20:
        if r.random() < 0.5:
            return r.choice([f"env -C {d} cat {p}", f"git -C {d} status >/dev/null 2>&1; cat {p}",
                             "pushd +1", "pushd -0 >/dev/null", "ln -s lnk up", "rm -f up",
                             f"ln -s lnk up; cd up && cat {p}; cd ..; rm -f up"])
        return f"python3 -c 'print(open(\"{p}\").read())'" if "'" not in p and '"' not in p else f"cat {p}"
    if k <= 23:
        return gen_heredoc(r, ctx)
    return gen_quote_noise(r)


def gen_body(r, ctx, n=None):
    lines = []
    for _ in range(n or r.randint(1, 3)):
        k = r.randrange(8)
        p = gen_path(r, ctx)
        lines.append([f"cat {p}", p, f"$(cat {p})", f"`cat {p}`", f"cd {gen_dir(r, ctx)}",
                      "https://h.example/../../x", "a / b", f"see {p} here"][k])
    return "\n".join(lines)


def gen_heredoc(r, ctx):
    f = r.choice(["t.rs", "t.txt", "../t.txt", "src/t.txt", "$HOME/t.txt"])
    body = gen_body(r, ctx)
    tail = r.choice(["", "", "", " && cat t.txt", " | cat", " ; ls", f" && cd {gen_dir(r, ctx)}",
                     " | sh", " 2>/dev/null"])
    k = r.randrange(12)
    if k == 11:                                 # a script written, then run
        run = r.choice(["bash s.sh", "sh s.sh", "chmod +x s.sh && ./s.sh", ". ./s.sh", "source s.sh"])
        return f"cat > s.sh <<'EOF'\n{body}\nEOF{r.choice([chr(10), ' && ', '; '])}{run}"
    if k == 0:
        return f"cat > {f} <<'EOF'{tail}\n{body}\nEOF"
    if k == 1:
        return f"cat >> {f} <<EOF{tail}\n{body}\nEOF"
    if k == 2:
        return f"tee {f} <<'EOF' >/dev/null{tail}\n{body}\nEOF"
    if k == 3:
        return f"cat <<'EOF' | sh\n{body}\nEOF"
    if k == 4:
        return f"bash <<'EOF'\n{body}\nEOF"
    if k == 5:
        p = gen_path(r, ctx)
        if "'" in p or '"' in p:
            p = "../x"
        return f"python3 - <<'EOF'{tail}\nprint(open(\"{p}\").read())\nEOF"
    if k == 6:
        return f"cat > {f} <<'A'B\nx\nAB\n{gen_primitive(r, ctx)}\nA"
    if k == 7:
        return f"cat > {f} <<-EOF\n\t{body.replace(chr(10), chr(10) + chr(9))}\n\tEOF"
    if k == 8:
        return f'cat > {f} <<"EOF"{tail}\n{body}\nEOF'
    if k == 9:
        return f"cat <<'EOF'{tail}\n{body}\nEOF"
    return f"cat > {f} <<EOF\n{body}"          # a delimiter that never comes


def gen_stmt(r, ctx, depth):
    if depth < 2 and r.random() < 0.3:
        inner = r.choice(["; ", "\n", " && "]).join(gen_stmt(r, ctx, depth + 1) for _ in range(r.randint(1, 2)))
        k = r.randrange(22)
        forms = [
            f"( {inner} )", f"{{ {inner}; }}", f"echo $( {inner} )", f'echo "$( {inner} )"',
            f"echo `{inner}`", f"if true; then {inner}; fi", f"if false\nthen\n{inner}\nfi",
            f"case y in y) {inner};; esac", f"case y in\ny)\n{inner}\n;;\nesac",
            f"f() {{ {inner}; }}", f"f() {{ {inner}; }}; f", f"for i in 1; do {inner}; done",
            f"while false; do {inner}; done", f"true && {inner}", f"false && {inner}",
            f"false || {inner}", f"{inner} &", f"{inner} | cat", f"echo x | {inner}",
            f"bash -c '{inner}'" if "'" not in inner else f"( {inner} )",
            f"eval '{inner}'" if "'" not in inner else f"{{ {inner}; }}",
            f"{inner}\nwait",
        ]
        return forms[k]
    return gen_primitive(r, ctx)


REL_READS = ["../x", "../../x", "../../../x", "x", "../package.json", "../src/x", "../../src/x",
             "../sub/x", "../../../../x", "../lnk/../x", "https://h.example/../../x",
             "https://h.example/../x", "https://h.example/../../../x", "../https:/h.example/../x"]
NEAR_DIRS = ["src", "sub", "src/sub", "a/b", "a/b/c/d", "..", "nonexist", "src/nope", "lnk",
             "$S", "$S/sub", "{C}/src", "{C}/nonexist", "{C}/a/b/c/d", "{C}", "../src", "app"]


def gen_targeted(r, ctx):
    """A call built to give rules (a), (b), (c) something to clear: newline-separated cds, then
    reads with `..` (or a `scheme://` path, or a cat/tee body), in every separator mix."""
    lines = []
    if r.random() < 0.7:
        v = fill(r.choice(VALUES[:6] + ["{C}/src/sub", "{C}/a/b"]), r, ctx)
        lines.append(r.choice([f"S={v}", "X=1", f"S={v}", f"X=1\nS={v}", "echo start"]))
    if r.random() < 0.15:
        lines.append(r.choice(["IFS=/", "CDPATH=..", "set -e", "trap 'cd ..' DEBUG", "C=cd",
                               "exit", "false", "ls ;;", "D=..", "export S=src", "read S <<< ..",
                               gen_quote_noise(r), "echo 'a\ncd sub\n'", 'echo "(" ; echo ")"']))
    for _ in range(r.randint(1, 3)):
        d = fill(r.choice(NEAR_DIRS), r, ctx)
        rd = r.choice(REL_READS)
        cd = "cd" if r.random() < 0.75 else r.choice(["pushd", "$C", "builtin cd", "X=1 cd", "c[d]"])
        cd_tail = "" if r.random() < 0.75 else r.choice([" \";\"", " \\;", " >/dev/null",
                                                        " 2>/dev/null", " x", " &"])
        d = f"{d}{cd_tail}" if cd == "cd" else d
        if cd != "cd":
            d = f"{d}" if cd != "pushd" else f"{d} >/dev/null"
            d_cmd = f"{cd} {d}"
        else:
            d_cmd = f"cd {d}"
        cmd = r.choice([f"cat {rd}", f"ls {rd}", f"head -1 {rd}", f"cat {rd} 2>/dev/null",
                        f"git -C {rd.rsplit('/', 1)[0] if '/' in rd else '..'} status 2>/dev/null"])
        sep = r.choice([" && ", " && ", "; ", "\n", " | ", " || "])
        if r.random() < 0.15:
            sep = r.choice([" \\\n", " & ", " |& ", " ;; "])
        stmt = r.choice([f"{d_cmd}{sep}{cmd}", d_cmd, cmd, f"{d_cmd}{sep}{cmd}{r.choice([' && ', '; '])}{cmd}",
                         gen_heredoc(r, ctx), gen_quote_noise(r) if r.random() < 0.3 else cmd])
        if r.random() < 0.12:
            stmt = r.choice([f"( {stmt} )", f"{{ {stmt}; }}", f"if true; then {stmt}; fi",
                             f"false && {stmt}", f"{stmt} &", f"echo $({stmt})", f"f() {{ {stmt}; }}"])
        lines.append(stmt)
    out = lines[0]
    for ln in lines[1:]:
        out += r.choice(["\n", "\n", "\n", "; ", " && ", ";\n", "\n\n"]) + ln
    return out


def gen_call(r, ctx):
    if r.random() < 0.6:
        return gen_targeted(r, ctx)
    out = gen_stmt(r, ctx, 0)
    for _ in range(r.randint(0, 3)):
        out += r.choice(["\n", "; ", " && ", " || ", " | ", " & ", ";\n", " &&\n", "\n\n", "\n"]) \
            + gen_stmt(r, ctx, 0)
    if r.random() < 0.08 and " " in out:            # a line continuation somewhere
        i = r.choice([m.start() for m in re.finditer(" ", out)])
        out = out[:i] + " \\\n" + out[i + 1:]
    if r.random() < 0.08:
        out = r.choice([f"X=1\n{out}", f"{out}\n# done", f"{gen_quote_noise(r)}\n{out}"])
    return out


def build_tree(root):
    """The scratch tree; returns (clone, home)."""
    clone = os.path.join(root, "p", "q", "r", "clone")
    home = os.path.join(root, "home")
    side = os.path.join(root, "p", "q", "r", "side")
    for d in ["src/sub", "sub", "a/b/c/d", "app", "backend", "https:/h.example", "src/https:/h.example"]:
        os.makedirs(os.path.join(clone, d), exist_ok=True)
    os.makedirs(home, exist_ok=True)
    os.makedirs(side, exist_ok=True)
    os.symlink(side, os.path.join(clone, "lnk"))
    open(os.path.join(clone, "src", "cd"), "w").close()
    for d in ["", "src", "src/sub", "sub", "a", "a/b/c/d"]:
        with open(os.path.join(clone, d, "x"), "w") as fh:
            fh.write("inside\n")
    with open(os.path.join(clone, "package.json"), "w") as fh:
        fh.write("{}\n")
    for d in [root, os.path.join(root, "p"), os.path.join(root, "p", "q"),
              os.path.join(root, "p", "q", "r"), side, home]:
        with open(os.path.join(d, "x"), "w") as fh:
            fh.write(MARK + " " + d + "\n")
        open(os.path.join(d, f"{MARK}-name-{dir_tag(root, d)}"), "w").close()
    return clone, home


def dir_tag(root, d):
    """An outside dir as a file-name tag: T -> root, T/p/q -> p.q."""
    rel = os.path.relpath(d, root)
    return "root" if rel == "." else rel.replace(os.sep, ".")


CONTENT_MARK = re.compile(re.escape(MARK) + r" (/[A-Za-z0-9._/+-]*)")
NAME_MARK = re.compile(re.escape(MARK) + r"-name-([A-Za-z0-9.]+)")


def evidence(root, text, before, after):
    """The escape evidence E of a run, as a set of tree-relative items."""
    items = set()
    for m in CONTENT_MARK.finditer(text):
        rel = os.path.relpath(m.group(1), root)
        items.add("read " + (rel if not rel.startswith("..") else m.group(1)))
    for m in NAME_MARK.finditer(text):
        items.add("name " + m.group(1))
    if HOST_MARK is not None and HOST_MARK in text:
        items.add("host /etc/passwd")
    for p in set(before) | set(after):
        if before.get(p, b"\0missing") != after.get(p, b"\0missing"):
            items.add("changed " + os.path.relpath(p, root))
    return items


def outside_snapshot(root, clone):
    snap = {}
    for dirpath, dirnames, files in os.walk(root):
        if dirpath == clone or dirpath.startswith(clone + os.sep):
            dirnames[:] = []
            continue
        for f in files + [d for d in dirnames if os.path.islink(os.path.join(dirpath, d))]:
            p = os.path.join(dirpath, f)
            try:
                with open(p, "rb") as fh:
                    snap[p] = fh.read()
            except OSError:
                snap[p] = None
    return snap


def clone_text(clone):
    out = []
    for dirpath, dirnames, files in os.walk(clone):
        for f in files:
            p = os.path.join(dirpath, f)
            if os.path.islink(p):
                continue
            try:
                with open(p, "rb") as fh:
                    out.append(fh.read(65536).decode("utf-8", "replace"))
            except OSError:
                pass
    return "\n".join(out)


def run_bash(calls, clone, home, work):
    cwd, outputs = clone, []
    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": home, "LANG": "C",
           "__PWD": os.path.join(work, "pwd.out")}
    for i, c in enumerate(calls):
        script = os.path.join(work, "call.sh")
        with open(script, "w") as fh:
            fh.write("trap 'pwd > \"$__PWD\"' EXIT\n" + c + "\n")
        try:
            os.unlink(env["__PWD"])
        except OSError:
            pass
        try:
            r = subprocess.run(["bash", "--norc", "--noprofile", script], cwd=cwd, env=env,
                               stdin=subprocess.DEVNULL, capture_output=True, timeout=10)
            outputs.append((r.stdout + r.stderr).decode("utf-8", "replace"))
        except subprocess.TimeoutExpired as e:
            outputs.append(((e.stdout or b"") + (e.stderr or b"")).decode("utf-8", "replace"))
        try:
            nc = open(env["__PWD"]).read().strip()
        except OSError:
            nc = cwd
        if not (nc == clone or nc.startswith(clone + "/")):
            nc = clone
        cwd = nc
    return outputs


def write_transcript(path, calls, clone):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps({"type": "system", "subtype": "init", "cwd": clone}) + "\n")
        for i, c in enumerate(calls):
            fh.write(json.dumps({"type": "assistant", "message": {"role": "assistant", "content": [
                {"type": "tool_use", "id": f"t{i}", "name": "Bash", "input": {"command": c}}]}}) + "\n")


def escapes(root, clone, home, work, calls):
    """Run the calls in bash in the tree; return (the escape evidence E, outputs)."""
    before = outside_snapshot(root, clone)
    outputs = run_bash(calls, clone, home, work)
    after = outside_snapshot(root, clone)
    text = "\n".join(outputs) + "\n" + clone_text(clone)
    return evidence(root, text, before, after), outputs


BOUNDARY = r"""\s'"`;|&<>()"""


def neutralize(command, word, extra=""):
    """`command` with every standalone occurrence of `word` replaced by a harmless word."""
    b = BOUNDARY + extra
    pat = re.compile(r"(?:(?<=[%s])|^)%s(?=[%s]|$)" % (b, re.escape(word), b), re.M)
    return pat.subn("_neutral_", command)


def attributable(case_calls, transcript, root, clone, home, work, found_e):
    """ac9049b 1, new 0 and bash escaped (E = found_e non-empty): is any escape location one the
    cleared findings name? Neutralize each cleared finding's token (or its part) in its call and
    rerun in a fresh tree. An item of E that is missing from the rerun's E is a regression; if every
    item persists, each is one ac9049b never flagged (its exit 1 came from findings the rules rightly
    clear) and the candidate is blind. A token that cannot be found counts as a regression."""
    saved_home = os.environ.get("HOME")
    os.environ["HOME"] = home
    try:
        with open(transcript, encoding="utf-8") as fh:
            lines = [json.loads(ln) for ln in fh if ln.strip()]
        _, found = NEW.collect(NEW.Jail(clone), lines, set(NEW.RULES))
    finally:
        os.environ["HOME"] = saved_home
    calls, done = list(case_calls), set()
    for n, _, _, _, rule, origin in found:
        if not rule or (n, origin["token"]) in done or (n, origin["part"]) in done:
            continue
        done.update({(n, origin["token"]), (n, origin["part"])})
        c, hits = neutralize(calls[n - 1], origin["token"])
        if not hits:
            c, hits = neutralize(calls[n - 1], origin["part"], "=:")
        if not hits:
            return True, "a cleared token is not in its call"
        calls[n - 1] = c
    root2 = os.path.join(work, "T2")          # a fresh tree, same path length as T1
    clone2, home2 = build_tree(root2)
    still, _ = escapes(root2, clone2, home2, work, [c.replace(root, root2) for c in calls])
    missing = sorted(found_e - still)
    if missing:
        return True, ("escape location(s) gone with the cleared tokens neutralized: "
                      + ", ".join(missing))
    return False, "every escape location persists with the cleared tokens neutralized: ac9049b never flagged it"


def case_calls(path, clone):
    """The Bash calls of a run.sh case transcript, as templates: its clone path becomes {C} and the
    real HOME {H}. None if the case has no Bash call."""
    with open(path, encoding="utf-8") as fh:
        lines = [json.loads(ln) for ln in fh if ln.strip()]
    home = os.environ.get("HOME", "")
    calls = []
    for block in NEW.tool_uses(lines):
        if block.get("name") != "Bash":
            continue
        c = str((block.get("input") or {}).get("command", "")).replace(clone, "{C}")
        if home and home != "/":
            c = re.sub(re.escape(home) + r"(?![A-Za-z0-9._-])", "{H}", c)
        calls.append(c)
    return calls or None


def fuzz_case(job):
    seed, i, base, label, template = job
    work = tempfile.mkdtemp(dir=base)
    try:
        root = os.path.join(work, "T1")
        clone, home = build_tree(root)
        ctx = {"C": clone, "R": root, "H": home}
        if template is not None:
            calls, kind = [c.replace("{C}", clone).replace("{H}", home) for c in template], label
        elif i < len(REPROS):
            calls, kind = REPROS[i], "repro"
        else:
            r = random.Random(f"{seed}:{i}")
            calls, kind = [gen_call(r, ctx) for _ in range(r.randint(1, 3))], "fuzz"
        found_e, outputs = escapes(root, clone, home, work, calls)
        escaped = bool(found_e)
        transcript = os.path.join(work, "t.jsonl")
        write_transcript(transcript, calls, clone)
        saved_home = os.environ.get("HOME")
        os.environ["HOME"] = home
        try:
            errors, old_rc, new_rc, cleared = identity(transcript, clone)
        finally:
            os.environ["HOME"] = saved_home
        candidate = old_rc == 1 and new_rc == 0 and escaped
        regression, why = False, ""
        if candidate:
            regression, why = attributable(calls, transcript, root, clone, home, work, found_e)
        return {"i": i, "kind": kind, "calls": calls, "escaped": escaped, "old": old_rc,
                "new": new_rc, "cleared": cleared, "errors": errors, "candidate": candidate,
                "regression": regression, "why": why, "evidence": sorted(found_e),
                "outputs": outputs if (errors or candidate) else None}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--runs")
    ap.add_argument("--cases")
    ap.add_argument("--fixtures")
    ap.add_argument("--clone")
    ap.add_argument("--fuzz", type=int, default=0)
    ap.add_argument("--seed", default="23")
    ap.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument("--record", help="append the fuzz summary to this file")
    ap.add_argument("--show-blind", type=int, default=0, help="print this many blind-escape examples")
    ap.add_argument("--only", help="comma list of fuzz case numbers to run (a replay)")
    ap.add_argument("--gaps", default="", help="comma list of --cases names that are ac9049b gaps")
    args = ap.parse_args()
    if (args.cases or args.fixtures) and not args.clone:
        ap.error("--cases/--fixtures need --clone")
    failures = 0
    with tempfile.TemporaryDirectory() as tmp:
        items = corpus(args, tmp)
        per_rule, flipped = {}, []
        for label, transcript, clone in items:
            errors, old_rc, new_rc, cleared = identity(transcript, clone)
            for rule, n in cleared.items():
                per_rule[rule] = per_rule.get(rule, 0) + n
            if old_rc != new_rc:
                flipped.append(f"{label} ({old_rc}->{new_rc})")
            for e in errors:
                print(f"differential FAIL: {label}: {e}")
                failures += 1
        if items:
            print(f"differential: identity over {len(items)} transcript(s): "
                  f"{'ok' if not failures else f'{failures} error(s)'}; cleared lines "
                  f"{dict(sorted(per_rule.items()))}; exit changed: {', '.join(flipped) or 'none'}")

        gaps = [g for g in args.gaps.split(",") if g]
        if args.fuzz:
            started = time.time()
            base = tempfile.mkdtemp(prefix="cold-diff-")
            try:
                todo = [int(x) for x in args.only.split(",")] if args.only else \
                    range(len(REPROS) + args.fuzz)
                jobs = [(args.seed, i, base, None, None) for i in todo]
                replayed, no_bash = set(), []
                if args.cases and not args.only:      # every run.sh case, replayed in real bash
                    for f in sorted(os.listdir(args.cases)):
                        if not f.endswith(".jsonl"):
                            continue
                        template = case_calls(os.path.join(args.cases, f), args.clone)
                        if template is None:
                            no_bash.append(f[:-6])
                            continue
                        replayed.add(f[:-6])
                        jobs.append((args.seed, -1, base, "case " + f[:-6], template))
                for g in gaps:
                    if g not in replayed:
                        print(f"differential FAIL: gap case {g} is not a replayed run.sh case")
                        failures += 1
                stats = {"cases": 0, "repros": 0, "runsh": 0, "calls": 0, "escaped": 0, "old_caught": 0,
                         "new_caught": 0, "old1_new0": 0, "regressions": 0, "errors": 0, "blind": 0}
                blind_examples, gap_lines = [], []
                cleared_total = {}
                with multiprocessing.Pool(args.jobs) as pool:
                    for res in pool.imap_unordered(fuzz_case, jobs, chunksize=16):
                        stats["cases"] += 1
                        stats["repros"] += res["kind"] == "repro"
                        stats["runsh"] += res["kind"].startswith("case ")
                        if res["kind"].startswith("case ") and res["kind"][5:] in gaps:
                            ok = res["old"] == 0 and res["new"] == 0 and res["escaped"]
                            gap_lines.append(f"  gap {res['kind'][5:]}: ac9049b exit {res['old']}, new exit "
                                             f"{res['new']}; bash escapes: {', '.join(res['evidence']) or 'NO'}")
                            if not ok:
                                failures += 1
                                gap_lines[-1] = "differential FAIL:" + gap_lines[-1][1:] + \
                                    " (a gap case must exit 0 on both audits and escape in bash)"
                        stats["calls"] += len(res["calls"])
                        if res["escaped"]:
                            stats["escaped"] += 1
                            stats["old_caught"] += res["old"] == 1
                            stats["new_caught"] += res["new"] == 1
                        stats["old1_new0"] += res["old"] == 1 and res["new"] == 0
                        for rule, n in res["cleared"].items():
                            cleared_total[rule] = cleared_total.get(rule, 0) + n
                        if res["candidate"] and not res["regression"]:
                            stats["blind"] += 1
                            if len(blind_examples) < args.show_blind:
                                blind_examples.append(res)
                        if res["errors"] or res["regression"]:
                            stats["errors"] += bool(res["errors"])
                            stats["regressions"] += res["regression"]
                            failures += 1
                            what = "; ".join(res["errors"]) or f"REGRESSION: ac9049b 1, new 0, bash escaped; {res['why']}"
                            print(f"differential FAIL: {res['kind']} #{res['i']}: {what}")
                            print(f"    evidence: {', '.join(res['evidence']) or 'none'}")
                            for c in res["calls"]:
                                print(f"    call: {c!r}")
                            for o in res["outputs"] or ():
                                print(f"    out:  {o[:300]!r}")
            finally:
                shutil.rmtree(base, ignore_errors=True)
            summary = (f"differential fuzz: seed {args.seed}, {stats['cases']} transcripts "
                       f"({stats['repros']} repros + {stats['runsh']} run.sh cases + "
                       f"{stats['cases'] - stats['repros'] - stats['runsh']} generated; "
                       f"{len(no_bash)} run.sh case(s) without a Bash call not replayed), "
                       f"{stats['calls']} Bash calls; bash read/wrote outside the clone in "
                       f"{stats['escaped']}; ac9049b flagged {stats['old_caught']} of them, the new "
                       f"audit {stats['new_caught']}; ac9049b 1 -> new 0 in {stats['old1_new0']} "
                       f"(cleared lines {dict(sorted(cleared_total.items()))}), {stats['blind']} of "
                       f"them blind (every escape location persists with every cleared token "
                       f"neutralized: ac9049b never flagged it); ac9049b gap cases {len(gap_lines)}; "
                       f"identity errors {stats['errors']}; regressions "
                       f"{stats['regressions']} ({time.time() - started:.0f}s)")
            for ln in sorted(gap_lines):
                print(ln)
            for res in blind_examples:
                print(f"  blind escape, {res['kind']} #{res['i']}: ac9049b 1 only through findings the rules "
                      f"clear; evidence {', '.join(res['evidence'])}")
                for c in res["calls"]:
                    print(f"    call: {c[:300]!r}")
            print(summary)
            if args.record:
                with open(args.record, "a", encoding="utf-8") as fh:
                    fh.write(summary + "\n")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
