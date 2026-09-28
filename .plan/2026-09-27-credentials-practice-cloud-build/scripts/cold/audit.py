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
(so `/etc/x` is a path, a route string like `/api/v1/users` is not). A `//...` part right after a
`:` (the authority of `scheme://host/...`) is not a path on its own; the whole `scheme://...` word
is still resolved from the cwd if it holds a `..`. The Bash cwd is simulated across calls, starting
at the clone, so `cd src && cat ../x` stays inside. An unquoted newline at the top level of the
command line separates commands as `;` does (not one in quotes, after a backslash, or inside
`( )`, `$( )` or backticks), so a `cd` at the start of the next line moves the cwd.

Heredocs (`<<` / `<<-`, quoted delimiter or not): the body is split off the command line. A body
fed to a shell (bash, sh, zsh, dash, ksh, source, ., eval anywhere on the operator's line) is
audited as shell, like any command. Any other body is data: every check still runs on its tokens,
except that a `~` is not expanded (bash does no tilde expansion in a heredoc body, so Dart's
`ms ~/ 1000` is not $HOME). An unquoted-delimiter body's $(...) and `...` run, so they are shell.
A body that `cat` or `tee` only writes to a file (a `>`/`>>` redirect on that simple command, and
for tee a file argument too; no pipe onward, no other redirect, not inside ( ), $( ) or backticks)
is audited the way Write content is: its tokens are not path-checked, but the target and the rest
of the command line are, and an unquoted body's $(...) and `...` are still audited as shell.

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

    def expand(self, token, tilde=True):
        if tilde and (token == "~" or token.startswith("~/")):
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


def mark_newlines(command):
    """Replace each command-separating newline with ` ; `: an unquoted newline at the top level of
    the command line (the newline that ends a comment counts). A newline in quotes, after a
    backslash, or inside ( ), $( ) or backticks is left as it is."""
    out, stack, i, n = [], [], 0, len(command)
    while i < n:
        c = command[i]
        top = stack[-1] if stack else None
        if top == "sq":
            if c == "'":
                stack.pop()
            out.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(command[i:i + 2])
            i += 2
            continue
        if top == "dq":
            if c == '"':
                stack.pop()
            elif command.startswith("$(", i):
                stack.append("sub")
                out.append("$(")
                i += 2
                continue
            elif c == "`":
                stack.append("bt")
            out.append(c)
            i += 1
            continue
        if c == "\n":
            out.append(" ; " if not stack else c)
            i += 1
            continue
        if c == "#" and (i == 0 or command[i - 1] in " \t\n;&|("):
            end = command.find("\n", i)
            end = n if end == -1 else end
            out.append(command[i:end])
            i = end
            continue
        if c == "'":
            stack.append("sq")
        elif c == '"':
            stack.append("dq")
        elif command.startswith("$(", i):
            stack.append("sub")
            out.append("$(")
            i += 2
            continue
        elif c == "`":
            if top == "bt":
                stack.pop()
            else:
                stack.append("bt")
        elif c == "(":
            stack.append("par")
        elif c == ")" and top in ("sub", "par"):
            stack.pop()
        out.append(c)
        i += 1
    return "".join(out)


def tokenize_data(text):
    """Tokens of a data heredoc body. Unbalanced quotes: split on the quotes too, so a quoted
    path ("/etc/x", '$HOME/x', "../x") still reaches the checks."""
    try:
        lex = shlex.shlex(text, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        return list(lex)
    except ValueError:
        return [t for t in re.split(r"(\s+|&&|\|\||[;|&()<>'\"`])", text) if t and not t.isspace()]


SHELL_WORDS = {"bash", "sh", "zsh", "dash", "ksh", "source", "eval"}
HEREDOC_OP = re.compile(r"""<<(-?)[ \t]*(?:'([^'\n]*)'|"([^"\n]*)"|(\\?)([^\s;&|<>()'"`]+))""")
HEREDOC_MARK = re.compile(r"@@HEREDOC_(\d+)@@")
DOT_COMMAND = re.compile(r"(?:^|[;&|(`]|\$\()\s*\.(?=\s)")


def feeds_shell(line):
    """True if a heredoc on this command line may be read by a shell (conservative: any shell
    word anywhere on the line, or `.` in command position)."""
    for word in re.findall(r"[^\s;&|()<>'\"`$]+", line):
        if os.path.basename(word) in SHELL_WORDS:
            return True
    return bool(DOT_COMMAND.search(line))


def split_heredocs(command):
    """Split heredoc bodies off a Bash command.

    Returns (text, bodies): text is the command with each body (and its delimiter line) replaced
    by a marker line `@@HEREDOC_<k>@@`; bodies[k] = (body, shell, quoted, to_file), to_file per
    writes_to_file(). A `<<` inside quotes is not an operator; a heredoc whose delimiter line never
    comes is left on the command line."""
    out, bodies, stack, pending = [], [], [], []
    i, n, line_start = 0, len(command), 0
    cmd_start = 0  # index in `out` where the current top-level logical line starts
    while i < n:
        c = command[i]
        top = stack[-1] if stack else None
        if top == "sq":
            if c == "'":
                stack.pop()
            out.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(command[i:i + 2])
            i += 2
            continue
        if c == "\n":
            out.append(c)
            i += 1
            if pending:
                line = command[line_start:i - 1]
                lines = command[i:].split("\n")
                j, parsed = 0, []
                for strip, delim, quoted, op_idx in pending:
                    body = []
                    while j < len(lines):
                        ln = lines[j]
                        j += 1
                        if (ln.lstrip("\t") if strip else ln) == delim:
                            to_file = op_idx is not None and not stack and \
                                writes_to_file(logical_line(out, cmd_start, op_idx, pending))
                            parsed.append(("\n".join(body), feeds_shell(line), quoted, to_file))
                            break
                        body.append(ln)
                    else:
                        break
                if len(parsed) == len(pending):
                    for p in parsed:
                        out.append(f"@@HEREDOC_{len(bodies)}@@\n")
                        bodies.append(p)
                    i += sum(len(ln) + 1 for ln in lines[:j])
                    i = min(i, n)
                pending = []
            line_start = i
            if not stack:
                cmd_start = len(out)
            continue
        if top == "dq":
            if c == '"':
                stack.pop()
            elif command.startswith("$(", i):
                stack.append("sub")
                out.append("$(")
                i += 2
                continue
            elif c == "`":
                stack.append("bt")
            out.append(c)
            i += 1
            continue
        # code context: top level, $( ), ( ), ` `
        if command.startswith("<<", i) and not command.startswith("<<<", i) \
                and (i == 0 or command[i - 1] != "<"):
            m = HEREDOC_OP.match(command, i)
            if m:
                delim = m.group(2) if m.group(2) is not None else \
                    m.group(3) if m.group(3) is not None else m.group(5)
                quoted = m.group(2) is not None or m.group(3) is not None or bool(m.group(4))
                pending.append((m.group(1) == "-", delim, quoted, None if stack else len(out)))
                out.append(m.group(0))
                i = m.end()
                continue
        if c == "#" and (i == 0 or command[i - 1] in " \t;&|("):
            end = command.find("\n", i)
            end = n if end == -1 else end
            out.append(command[i:end])
            i = end
            continue
        if c == "'":
            stack.append("sq")
        elif c == '"':
            stack.append("dq")
        elif command.startswith("$(", i):
            stack.append("sub")
            out.append("$(")
            i += 2
            continue
        elif c == "`":
            if top == "bt":
                stack.pop()
            else:
                stack.append("bt")
        elif c == "(":
            stack.append("par")
        elif c == ")" and top in ("sub", "par"):
            stack.pop()
        out.append(c)
        i += 1
    return "".join(out), bodies


DATA_WRITERS = {"cat", "tee"}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")


def logical_line(out, start, op_idx, pending):
    """The top-level logical line holding the heredoc operator at out[op_idx], with that operator
    as the word @@OP@@ and every other pending operator as @@HD@@."""
    others = {p[3] for p in pending} - {op_idx}
    parts = []
    for k in range(start, len(out)):
        parts.append(" @@OP@@ " if k == op_idx else " @@HD@@ " if k in others else out[k])
    return "".join(parts)


def writes_to_file(line):
    """True if the heredoc @@OP@@ on this top-level line is the stdin of a `cat` or `tee` whose
    output goes only to files: its simple command starts with cat/tee (after NAME=value words), has
    a `>`/`>>` redirect to a word, tee also has a file argument, it has no other redirect or
    operator word, it is not piped onward, and the line has no ( ), $( ) or backticks (so the
    simple command is exactly what bash runs). Anything else is False: the body keeps every check."""
    try:
        lex = shlex.shlex(line, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        tokens = list(lex)
    except ValueError:
        return False
    if any(t in ("(", ")") or "$(" in t or "`" in t for t in tokens):
        return False
    segments, cur = [], []
    for t in tokens:
        if t in SEPARATORS:
            segments.append((cur, t))
            cur = []
        else:
            cur.append(t)
    segments.append((cur, None))
    for words, after in segments:
        if "@@OP@@" in words:
            break
    else:
        return False
    if after in ("|", "|&"):
        return False
    k = 0
    while k < len(words) and ASSIGNMENT.match(words[k]):
        k += 1
    if k >= len(words) or words[k] not in DATA_WRITERS:
        return False
    cmd, rest = words[k], words[k + 1:]
    redirected, files, j = False, [], 0
    while j < len(rest):
        t = rest[j]
        if t in ("@@OP@@", "@@HD@@"):
            j += 1
            continue
        if t in (">", ">>"):
            if j > 0 and rest[j - 1].isdigit():
                return False  # maybe an fd redirect (`2>`), not stdout
            if j + 1 >= len(rest) or rest[j + 1].startswith("@@") or \
                    any(ch in rest[j + 1] for ch in "<>&|;"):
                return False
            redirected = True
            j += 2
            continue
        if any(ch in t for ch in "<>&|;"):
            return False
        if not t.startswith("-"):
            files.append(t)
        j += 1
    if not redirected:
        return False
    return cmd == "cat" or bool(files)


def substitutions(text):
    """The $(...) and `...` command substitutions in an unquoted heredoc body."""
    subs, i = [], 0
    while i < len(text):
        if text.startswith("$(", i):
            depth, j = 1, i + 2
            while j < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[j], 0)
                j += 1
            subs.append(text[i + 2:j - 1] if not depth else text[i + 2:])
            i = j
        elif text[i] == "`":
            j = text.find("`", i + 1)
            j = len(text) if j == -1 else j
            subs.append(text[i + 1:j])
            i = j + 1
        else:
            i += 1
    return subs


def audit_heredoc(jail, body, cwd):
    """Return (violations, new_cwd) for one heredoc body."""
    text, shell, quoted, to_file = body
    if shell:
        return audit_bash(jail, text, cwd)
    violations = []
    if not to_file:  # a body cat/tee only writes to a file is data, like Write content
        for tok in tokenize_data(text):
            violations += audit_token(jail, tok, cwd, tilde=False)
    if not quoted:
        for sub in substitutions(text):
            violations += audit_bash(jail, sub, cwd)[0]
    return violations, cwd


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
    command, bodies = split_heredocs(command)
    audited = set()
    tokens = tokenize(mark_newlines(command))
    command_start = True
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        marks = [int(k) for k in HEREDOC_MARK.findall(tok) if int(k) < len(bodies)]
        if marks:
            for k in marks:
                if k not in audited:
                    audited.add(k)
                    v, cwd = audit_heredoc(jail, bodies[k], cwd)
                    violations += v
            tok = HEREDOC_MARK.sub(" ", tok)
            if not tok.strip():
                i += 1
                continue
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
    for k, body in enumerate(bodies):  # a marker the tokenizer lost is still audited
        if k not in audited:
            v, cwd = audit_heredoc(jail, body, cwd)
            violations += v
    return violations, cwd


def url_authority(delim, part):
    """A `//...` part right after a `:`: the authority of `scheme://host/...`, not a path."""
    return delim == ":" and part.startswith("//")


def audit_token(jail, tok, cwd, tilde=True):
    violations = []
    pieces = re.split(r"([=:])", tok)
    word = ""  # the text since the last `=`: what bash would open if it were a path
    for idx in range(0, len(pieces), 2):
        part = pieces[idx]
        delim = pieces[idx - 1] if idx else ""
        word = word + ":" + part if delim == ":" else part
        if not part:
            continue
        if url_authority(delim, part):
            whole = jail.expand(word, tilde)
            if has_dotdot(whole):
                p = norm(os.path.join(cwd, whole))
                if not jail.ok(p):
                    violations.append(("escape", f"`{whole}` resolves outside the clone (-> {p})"))
            continue
        part = jail.expand(part, tilde)
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
