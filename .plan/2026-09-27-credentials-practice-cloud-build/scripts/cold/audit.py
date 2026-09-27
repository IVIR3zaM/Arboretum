#!/usr/bin/env python3
"""audit.py <transcript.jsonl> <clone> — jail audit of a cold run.

Reads a Claude Code stream-json transcript (or a session .jsonl, same shape) and lists every tool
call that broke the jail:
  - file:  a file tool (Read, Write, Edit, Glob, Grep, ...) whose path is outside the clone;
  - bash:  a Bash command naming an absolute path outside the clone;
  - escape: a Bash command leaving the clone with `..` (a `cd ..` out of it, or a relative path
            that resolves outside it);
  - web:   any web tool (WebFetch, WebSearch, a server-side web search).
Toolchain caches and SDK dirs (cargo, rustup, pub cache, the flutter/dart/node SDKs), the system
binary dirs and /dev/null & co. are allowed. Extra allowed prefixes: COLD_AUDIT_ALLOW (colon-sep).

A Bash token counts as an absolute path only if its first component exists at `/` on this machine
(so `/etc/x` is a path, a route string like `/api/v1/users` is not). The Bash cwd is simulated
across calls, starting at the clone, so `cd src && cat ../x` stays inside.

Exit 0: clean. Exit 1: violations (each printed). Exit 2: usage or unreadable transcript.
"""
import json
import os
import re
import shlex
import shutil
import sys

FILE_TOOLS = {"Read", "Write", "Edit", "MultiEdit", "NotebookEdit", "Glob", "Grep", "LS"}
PATH_KEYS = ("file_path", "notebook_path", "path")
WEB_TOOL_RE = re.compile(r"web|browser|fetch", re.IGNORECASE)
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
CD_WORDS = {"cd", "pushd"}


def norm(p):
    return os.path.normpath(p)


class Jail:
    def __init__(self, clone):
        self.home = os.path.expanduser("~")
        abs_clone = norm(os.path.abspath(clone))
        self.roots = {abs_clone, norm(os.path.realpath(clone))}
        self.clone = abs_clone
        self.allowed = self._allowed_prefixes()

    def _allowed_prefixes(self):
        h = self.home
        allowed = {
            "/dev/null", "/dev/stdin", "/dev/stdout", "/dev/stderr", "/dev/tty", "/dev/fd",
            "/bin", "/sbin", "/usr/bin", "/usr/sbin", "/usr/local/bin",
            os.path.join(h, ".cargo"), os.path.join(h, ".rustup"), os.path.join(h, ".pub-cache"),
            os.path.join(h, ".npm"), os.path.join(h, "flutter"), os.path.join(h, "flutter-sdk"),
            "/opt/flutter",
        }
        for var in ("CARGO_HOME", "RUSTUP_HOME", "PUB_CACHE", "FLUTTER_ROOT"):
            if os.environ.get(var):
                allowed.add(norm(os.environ[var]))
        # SDK roots of the toolchains on PATH (e.g. /opt/node22, a flutter checkout). A binary that
        # lives straight in a system dir only allows its bin dir, never / or /usr.
        for tool in ("flutter", "dart", "cargo", "rustc", "rustup", "node", "npm"):
            found = shutil.which(tool)
            if not found:
                continue
            for p in {found, os.path.realpath(found)}:
                bindir = os.path.dirname(p)
                root = os.path.dirname(bindir)
                allowed.add(bindir)
                if root not in ("/", "/usr", "/usr/local", "/opt", self.home, "/root", "/home"):
                    allowed.add(root)
        for extra in os.environ.get("COLD_AUDIT_ALLOW", "").split(":"):
            if extra:
                allowed.add(norm(extra))
        return allowed

    @staticmethod
    def _under(path, prefix):
        return path == prefix or path.startswith(prefix.rstrip("/") + "/")

    def inside(self, path):
        return any(self._under(path, r) for r in self.roots)

    def ok(self, path):
        return self.inside(path) or any(self._under(path, a) for a in self.allowed)

    def resolve(self, path, cwd):
        path = self.expand(path)
        if not os.path.isabs(path):
            path = os.path.join(cwd, path)
        return norm(path)

    def expand(self, token):
        if token == "~" or token.startswith("~/"):
            token = self.home + token[1:]
        for var in ("${HOME}", "$HOME"):
            if token.startswith(var):
                token = self.home + token[len(var):]
        return token


def tokenize(command):
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        return list(lex)
    except ValueError:
        # unbalanced quotes (heredocs, odd quoting): fall back to a plain split
        return [t for t in re.split(r"(\s+|&&|\|\||[;|&()<>])", command) if t and not t.isspace()]


def looks_absolute(token):
    """An absolute path whose first component exists on this machine (not a route string)."""
    if token == "/":
        return True
    if not token.startswith("/") or token.startswith("//"):
        return False
    first = token.split("/")[1]
    return bool(first) and os.path.exists("/" + first)


def has_dotdot(token):
    return ".." in token.split("/")


def audit_bash(jail, command, cwd):
    """Return (violations, new_cwd)."""
    violations = []
    tokens = tokenize(command)
    command_start = True
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in SEPARATORS:
            command_start = True
            i += 1
            continue
        if command_start and tok in CD_WORDS:
            j = i + 1
            while j < len(tokens) and tokens[j].startswith("-") and tokens[j] != "-":
                j += 1
            if j < len(tokens) and tokens[j] not in SEPARATORS:
                arg = tokens[j]
                i = j + 1
            else:
                arg = "~"
                i = j
            if arg != "-":
                target = jail.resolve(arg, cwd)
                if not jail.ok(target):
                    violations.append(("escape", f"`{tok} {arg}` leaves the clone (-> {target})"))
                cwd = target
            command_start = False
            continue
        command_start = False
        i += 1
        violations += audit_token(jail, tok, cwd)
    return violations, cwd


def audit_token(jail, tok, cwd):
    violations = []
    for part in re.split(r"[=:]", tok):
        if not part:
            continue
        part = jail.expand(part)
        if looks_absolute(part):
            p = norm(part)
            if not jail.ok(p):
                violations.append(("bash", f"names outside path {part}"))
        elif has_dotdot(part):
            p = jail.resolve(part, cwd)
            if not jail.ok(p):
                violations.append(("escape", f"`{part}` resolves outside the clone (-> {p})"))
    return violations


def audit_file_tool(jail, name, inp):
    violations = []
    for key in PATH_KEYS:
        val = inp.get(key)
        if isinstance(val, str) and val:
            p = jail.resolve(val, jail.clone)
            if not jail.ok(p):
                violations.append(("file", f"{key}={val} is outside the clone"))
    if name == "Glob":
        pat = inp.get("pattern")
        if isinstance(pat, str) and (pat.startswith("/") or pat.startswith("~") or has_dotdot(pat)):
            p = jail.resolve(pat, jail.clone)
            if not jail.ok(p):
                violations.append(("file", f"pattern={pat} reaches outside the clone"))
    return violations


def tool_uses(lines):
    for obj in lines:
        if not isinstance(obj, dict) or obj.get("type") != "assistant":
            continue
        content = (obj.get("message") or {}).get("content") or []
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get("type") in ("tool_use", "server_tool_use"):
                yield block


def main(argv):
    if len(argv) != 3:
        print("usage: audit.py <transcript.jsonl> <clone>", file=sys.stderr)
        return 2
    transcript, clone = argv[1], argv[2]
    if not os.path.isdir(clone):
        print(f"audit: clone dir not found: {clone}", file=sys.stderr)
        return 2
    try:
        raw = open(transcript, encoding="utf-8").read().splitlines()
    except OSError as e:
        print(f"audit: cannot read transcript: {e}", file=sys.stderr)
        return 2
    lines, bad = [], 0
    for line in raw:
        if not line.strip():
            continue
        try:
            lines.append(json.loads(line))
        except json.JSONDecodeError:
            bad += 1
    if not lines:
        print(f"audit: no JSON lines in {transcript}", file=sys.stderr)
        return 2

    jail = Jail(clone)
    cwd = jail.clone
    found = []
    count = 0
    for block in tool_uses(lines):
        count += 1
        name = block.get("name", "?")
        inp = block.get("input") or {}
        if not isinstance(inp, dict):
            inp = {}
        if block.get("type") == "server_tool_use" or WEB_TOOL_RE.search(name):
            found.append((count, name, "web", f"web tool used: {json.dumps(inp)[:200]}"))
            continue
        if name == "Bash":
            v, cwd = audit_bash(jail, str(inp.get("command", "")), cwd)
            if not jail.inside(cwd):
                cwd = jail.clone  # Claude Code puts the shell back in the project dir
            found += [(count, name, k, d + f" | {str(inp.get('command', ''))[:200]!r}") for k, d in v]
        elif name in FILE_TOOLS or any(k in inp for k in PATH_KEYS):
            found += [(count, name, k, d) for k, d in audit_file_tool(jail, name, inp)]

    note = f" ({bad} non-JSON line(s) skipped)" if bad else ""
    if found:
        for n, name, kind, detail in found:
            print(f"VIOLATION [{kind}] call #{n} {name}: {detail}")
        print(f"audit: {len(found)} violation(s) in {count} tool call(s){note} — clone {jail.clone}")
        return 1
    print(f"audit: clean — {count} tool call(s) checked{note}, clone {jail.clone}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
