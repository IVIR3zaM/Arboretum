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

Heredocs (`<<` / `<<-`, quoted delimiter or not): the body is split off the command line. A body
fed to a shell (bash, sh, zsh, dash, ksh, source, ., eval anywhere on the operator's line) is
audited as shell, like any command. Any other body is data: every check still runs on its tokens,
except that a `~` is not expanded (bash does no tilde expansion in a heredoc body, so Dart's
`ms ~/ 1000` is not $HOME). An unquoted-delimiter body's $(...) and `...` run, so they are shell.

Clearance pass (N23, D23). The checks above are the ac9049b audit, unchanged: they decide every
finding. A second pass may then drop a finding, and only when one of three rules proves it
harmless; nothing is ever added, and when in doubt the finding stands. COLD_AUDIT_RULES picks the
rules (a comma list of a,b,c, or `none` for exactly the ac9049b output; default all three);
`--explain` also prints each dropped finding as `cleared (<rule>): <its VIOLATION line>`.
  (a) newline separator. The engine's tokenizer drops newlines, so a `cd` on a later line is missed.
      Rule (a) keeps its own cwd — known or unknown, from the clone, carried across calls — over a
      plain command: no $', comment, backslash (newline or not) outside quotes, ( ) { } ` $( ${ $[,
      &, compound or state-changing command word (if/for/case/function/source/eval/exec/exit/set/
      trap/...), CDPATH, IFS, symlink-making, or syntax error. A `cd D`/`pushd D`, first in its
      and-or list and not in a pipeline, with D literal (after `$NAME` from a bare earlier
      `NAME=<literal>` line) moves it: to an existing dir no symlink moves, or — for a missing D —
      only for the rest of its && chain on that line. Any other cd makes it unknown, until a cd
      to an existing absolute dir. A `..` finding on the command line clears if, read from the known
      cwd (and through the file system), it stays in the jail.
  (b) `scheme://`. A part after `scheme:` (not file:) with an authority is a path below a dir named
      `scheme:`; it clears if it cannot climb out of it, read from rule (a)'s known cwd.
  (c) cat/tee-to-file body. A data body with a clean delimiter, on a plain `cat >FILE` or
      `tee [-a] FILE... >FILE` with no other argument, redirect or pipe onward, is file content, as
      with the Write tool: its token findings clear. Not when an unquoted body holds a substitution,
      when anything could make cat/tee something else (hash, PATH=, functions, ...), or when a later
      command in the transcript may run the file.

Exit 0: clean. Exit 1: violations (each printed). Exit 2: usage, unreadable transcript, or an
unknown COLD_AUDIT_RULES value.
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
    by a marker line `@@HEREDOC_<k>@@`; bodies[k] = (body, shell, quoted). A `<<` inside quotes is
    not an operator; a heredoc whose delimiter line never comes is left on the command line."""
    out, bodies, stack, pending = [], [], [], []
    i, n, line_start = 0, len(command), 0
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
                for strip, delim, quoted in pending:
                    body = []
                    while j < len(lines):
                        ln = lines[j]
                        j += 1
                        if (ln.lstrip("\t") if strip else ln) == delim:
                            parsed.append(("\n".join(body), feeds_shell(line), quoted))
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
                pending.append((m.group(1) == "-", delim, quoted))
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


def audit_heredoc(jail, body, cwd, k=None, nested=None):
    """Return (violations, new_cwd) for one heredoc body (body k of its command)."""
    text, shell, quoted = body
    if shell:
        return audit_bash(jail, text, cwd, nested or "shell-body")
    violations = []
    for tok in tokenize_data(text):
        violations += audit_token(jail, tok, cwd, tilde=False,
                                  origin={"source": nested or "data-body", "body": k})
    if not quoted:
        for sub in substitutions(text):
            violations += audit_bash(jail, sub, cwd, nested or "body-subst")[0]
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


def audit_bash(jail, command, cwd, nested=None):
    """Return (violations, new_cwd). Each violation is (kind, detail, origin): origin names where
    the finding came from — source "token" or "cd" (a token of this command line, at `index` in
    its token list), "data-body" (a token of heredoc body `body`), or, for anything audited inside
    a shell-fed body or a body substitution, the `nested` source "shell-body" / "body-subst"."""
    violations = []
    command, bodies = split_heredocs(command)
    audited = set()
    tokens = tokenize(command)
    command_start = True
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        marks = [int(k) for k in HEREDOC_MARK.findall(tok) if int(k) < len(bodies)]
        if marks:
            for k in marks:
                if k not in audited:
                    audited.add(k)
                    v, cwd = audit_heredoc(jail, bodies[k], cwd, k, nested)
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
                arg, arg_index = tokens[j], j
                i = j + 1
            else:
                arg, arg_index = "~", None
                i = j
            if arg != "-":
                target = jail.resolve(arg, cwd)
                if not jail.ok(target):
                    violations.append(("escape", f"`{tok} {arg}` leaves the clone (-> {target})",
                                       {"source": nested or "cd", "index": arg_index, "token": arg,
                                        "part": arg, "dotdot": has_dotdot(arg)}))
                cwd = target
            command_start = False
            continue
        command_start = False
        i += 1
        violations += audit_token(jail, tok, cwd, origin={"source": nested or "token", "index": i - 1})
    for k, body in enumerate(bodies):  # a marker the tokenizer lost is still audited
        if k not in audited:
            v, cwd = audit_heredoc(jail, body, cwd, k, nested)
            violations += v
    return violations, cwd


def audit_token(jail, tok, cwd, tilde=True, origin=None):
    violations = []
    for pi, part in enumerate(re.split(r"[=:]", tok)):
        if not part:
            continue
        o = dict(origin or {}, token=tok, part_index=pi, part=part)
        part = jail.expand(part, tilde)
        if looks_absolute(part):
            p = norm(part)
            if not jail.ok(p):
                violations.append(("bash", f"names outside path {part}", o))
        elif has_dotdot(part):
            p = jail.resolve(part, cwd)
            if not jail.ok(p):
                violations.append(("escape", f"`{part}` resolves outside the clone (-> {p})",
                                   dict(o, dotdot=True)))
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


# ---------------------------------------------------------------------------------------------
# Clearance pass (N23, D23). Everything above is the verdict engine and is the ac9049b audit; the
# code below adds no finding. It drops an engine finding only when rule (a), (b) or (c) proves it
# harmless; when in doubt the finding stands.

RULES = ("a", "b", "c")
OP_CHARS = "();<>|&"
LIST_SEPS = {";", "&&", "||", "|"}
REDIRECTS = {">", ">>", "<", ">|", ">&", "<&", "&>", "&>>", "<>", "<<", "<<<"}
NAME_EQ = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)(\+?)=")
LITERAL = re.compile(r"[A-Za-z0-9._/+-]+\Z")          # a cd target rule (a) may follow
LITERAL_TOKEN = re.compile(r"[A-Za-z0-9._/+,=:@%-]+\Z")  # a token rule (a) may clear
COMMAND_WORD = re.compile(r"(?:[A-Za-z0-9._/+-]+|\[)\Z")
CLEAN_DELIM = re.compile(r"-?(?:'([A-Za-z_][A-Za-z0-9_]*)'|\"([A-Za-z_][A-Za-z0-9_]*)\"|([A-Za-z_][A-Za-z0-9_]*))\Z")
SCHEME = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*\Z")
# rule (a): command words that may branch, loop, run text as shell, end the shell early or change how
# cd, variables or later commands behave. A call with one of them in command position clears nothing.
A_REFUSE = {
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac",
    "select", "function", "time", "coproc", "!", "[[", "source", ".", "eval", "popd",
    "exec", "exit", "return", "logout", "set", "shopt", "trap", "builtin", "command", "enable",
    "alias", "unalias", "declare", "typeset", "export", "readonly", "local", "unset", "read",
    "mapfile", "readarray", "let", "fc", "history", "bind", "kill", "hash", "suspend", "ulimit",
    "getopts", "caller", "break", "continue", "wait", "fg", "bg", "disown", "compgen", "complete",
    "ln",                                               # a symlink the audit may not see later
}
# an option that makes a command resolve the words after it from another dir (git/make/tar -C ..)
CHDIR_OPTION = re.compile(r"-C|--?(?:directory|chdir|cwd|work-tree|git-dir|prefix|root)\b")
# commands that run a file they are given: a body written to a file one of them names later is code
RUNNERS = {"sh", "bash", "zsh", "dash", "ksh", "source", ".", "eval", "python", "python3", "node",
           "perl", "ruby", "php", "dart", "deno", "bun", "lua", "Rscript", "tclsh", "awk", "gawk",
           "env", "xargs", "exec", "sudo", "nohup", "timeout", "nice", "chmod", "install", "cp",
           "mv", "ln"}
A_WORDS = ("CDPATH", "IFS", "$$", "PWD=", "HOME=")      # any token holding one refuses (a)
SPECIAL_NAMES = {"IFS", "PWD", "OLDPWD", "HOME", "CDPATH", "PATH", "UID", "EUID", "PPID",
                 "SHELLOPTS", "BASHOPTS", "GROUPS", "RANDOM", "SRANDOM", "SECONDS", "LINENO",
                 "FUNCNAME", "HOSTNAME", "HISTFILE", "ENV"}
# rule (c): words that can make `cat`/`tee` something else, or feed a written file to a reader
C_REFUSE = {"eval", "source", ".", "alias", "enable", "hash", "shopt", "function", "exec",
            "builtin", "command", "set", "trap", "declare", "typeset", "export", "readonly",
            "local", "mkfifo", "mknod", "coproc"}
C_NAMES = {"PATH", "BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS"}


def enabled_rules():
    raw = os.environ.get("COLD_AUDIT_RULES")
    if raw is None or not raw.strip():
        return set(RULES)
    if raw.strip() == "none":
        return set()
    rules = {r.strip() for r in raw.split(",") if r.strip()}
    if rules - set(RULES):
        raise ValueError(f"COLD_AUDIT_RULES: unknown rule(s) {sorted(rules - set(RULES))}; "
                         "use a comma list of a,b,c or none")
    return rules


def shlex_line(line):
    """ac9049b's tokenizer on one line, but None where it would fall back to a plain split."""
    try:
        lex = shlex.shlex(line, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = ""
        return list(lex)
    except ValueError:
        return None


def lex_line(line, flags):
    """The words of one line as (text, raw, is_operator), quotes removed as shlex does. None if the
    line is not plain: an unclosed quote, a backslash outside quotes, or a word that starts with `#`
    (a comment in bash, a word to shlex). Adds to `flags`: "group" for ( ) { } outside quotes,
    "subst" for a backtick, `$(`, `${` or `$[` outside '...' (inside "..." too)."""
    toks, i, n = [], 0, len(line)
    while i < n:
        c = line[i]
        if c in " \t":
            i += 1
            continue
        if c in OP_CHARS:
            j = i
            while j < n and line[j] in OP_CHARS:
                j += 1
            op = line[i:j]
            if "(" in op or ")" in op:
                flags.add("group")
            toks.append((op, op, True))
            i = j
            continue
        if c == "#":
            return None
        j, text = i, []
        while j < n and line[j] not in " \t" and line[j] not in OP_CHARS:
            ch = line[j]
            if ch == "'":
                k = line.find("'", j + 1)
                if k < 0:
                    return None
                text.append(line[j + 1:k])
                j = k + 1
            elif ch == '"':
                k, buf = j + 1, []
                while k < n and line[k] != '"':
                    if line[k] == "`" or line[k] == "$" and line[k + 1:k + 2] in ("(", "{", "["):
                        flags.add("subst")
                    if line[k] == "\\" and k + 1 < n and line[k + 1] in '"\\':
                        buf.append(line[k + 1])
                        k += 2
                    else:
                        buf.append(line[k])
                        k += 1
                if k >= n:
                    return None
                text.append("".join(buf))
                j = k + 1
            elif ch == "\\":
                return None
            else:
                if ch in "{}":
                    flags.add("group")
                if ch == "`" or ch == "$" and line[j + 1:j + 2] in ("(", "{", "["):
                    flags.add("subst")
                text.append(ch)
                j += 1
        toks.append(("".join(text), line[i:j], False))
        i = j
    return toks


class Shape:
    """A Bash command as rules (a) and (c) read it: its lines, each a list of simple commands.

    `ok` is False unless the command is plain — no `$'`, no backslash-newline, no comment, no
    backslash outside quotes, every line quote-balanced — its tokens are exactly the engine's tokens,
    its heredoc operators are the ones split_heredocs split off (each with a clean delimiter) and it
    parses as a flat list of simple commands (no stray or doubled operator, no dangling && at the
    end). Each command is a dict: items (("word", index, text, raw) or ("redir", index, op, word)),
    prev ("start", ";", "&&", "||", "|", or "+&&" etc. for a line continuing an operator), next (the
    separator after it, "\n" at the end of its line) and line (its line number)."""

    def __init__(self, command):
        self.ok = False
        self.flags = set()
        self.text, self.bodies = split_heredocs(command)
        self.lines = []      # per line: list of commands; None for a heredoc marker line
        self.ops = []        # per body k: (line number, token index, quoted)
        self.words = []      # every word token: (index, text, raw)
        if "$'" in command or "\\\n" in self.text:
            return
        index, flat, cont, marker_next = 0, [], None, 0
        pending = []         # heredoc ops of the last code line, waiting for their marker lines
        for ln_no, line in enumerate(self.text.split("\n")):
            m = HEREDOC_MARK.fullmatch(line)
            if m:
                if not pending or int(m.group(1)) != marker_next or pending[0] != marker_next:
                    return
                pending.pop(0)
                marker_next += 1
                flat.append(line)
                index += 1
                self.lines.append(None)
                continue
            if pending:
                return
            toks = lex_line(line, self.flags)
            if toks is None or [t[0] for t in toks] != shlex_line(line):
                return
            if "@@HEREDOC_" in line:
                return
            cmds, cur = [], None
            k = 0
            while k < len(toks):
                text, raw, is_op = toks[k]
                if cur is None:
                    cur = {"items": [], "prev": ("+" + cont) if cont else (cmds[-1]["next"] if cmds else "start"),
                           "next": "\n", "line": ln_no}
                    cont = None
                if is_op and text in LIST_SEPS:
                    if not cur["items"]:
                        return
                    cur["next"] = text
                    cmds.append(cur)
                    cur = None
                elif is_op and text in REDIRECTS:
                    if k + 1 >= len(toks) or toks[k + 1][2]:
                        return
                    target = toks[k + 1]
                    if text == "<<":
                        if not CLEAN_DELIM.match(target[1]):
                            return
                        q = "'" in target[1] or '"' in target[1]
                        self.ops.append((ln_no, index, q))
                        pending.append(len(self.ops) - 1)
                    cur["items"].append(("redir", index, text, target))
                    self.words.append((index + 1, target[0], target[1]))
                    k += 1
                    index += 1
                elif is_op:
                    return          # ;; ;& & |& (( and the like
                else:
                    cur["items"].append(("word", index, text, raw))
                    self.words.append((index, text, raw))
                k += 1
                index += 1
            if cur is not None:
                cmds.append(cur)
            elif cmds and cmds[-1]["next"] in ("&&", "||", "|"):
                cont = cmds[-1]["next"]
            if cmds and cmds[-1]["next"] == "\n":
                cont = None
            flat += [t[0] for t in toks]
            self.lines.append(cmds)
        if cont or pending or len(self.ops) != len(self.bodies) or marker_next != len(self.bodies):
            return
        if flat != tokenize(self.text):
            return
        self.ok = True

    def commands(self):
        for cmds in self.lines:
            for c in cmds or ():
                yield c


def command_word(c):
    """The command word of a simple command: its first word that is not a leading assignment."""
    return next((it for it in c["items"] if it[0] == "word" and not NAME_EQ.match(it[3])), None)


def phys_ok(jail, path):
    """True if no symlink along `path` moves it: the kernel's path is the textual one."""
    real = os.path.realpath(path)
    if jail._under(path, jail.clone):
        return real == norm(os.path.join(os.path.realpath(jail.clone),
                                         os.path.relpath(path, jail.clone)))
    return real == path


def lands_ok(jail, cwd, part):
    """`part` resolved from `cwd`, textually and through the file system, stays in the jail."""
    joined = os.path.join(cwd, part)
    return jail.ok(norm(joined)) and jail.ok(os.path.realpath(joined))


class RuleA:
    """Rule (a)'s own cwd: known (a path) or unknown (None). It starts at the clone and carries
    across calls; a known cwd outside the clone resets to the clone after a call, as the engine's
    does. The engine's cwd is not touched."""

    def __init__(self, jail):
        self.jail = jail
        self.cwd = jail.clone

    def call(self, shape):
        """Simulate one Bash call; return {token index: cwd or None}, or None if (a) is refused."""
        res = self._simulate(shape)
        if res is None:
            self.cwd = None
            return None
        cwds, end = res
        if end is not None and not self.jail.inside(end):
            end = self.jail.clone
        self.cwd = end
        return cwds

    def _refused(self, shape):
        if not shape.ok or shape.flags & {"group", "subst"}:
            return True
        for _, text, raw in shape.words:
            if any(w in text for w in A_WORDS):
                return True
        for c in shape.commands():
            words = [it for it in c["items"] if it[0] == "word"]
            if not c["items"] or c["items"][0][0] == "redir":
                return True
            cmd = command_word(c)
            if cmd is None:
                continue
            if cmd[2] != cmd[3] or not COMMAND_WORD.match(cmd[2]) or cmd[2] in A_REFUSE:
                return True
            if cmd[2] == "printf" and any(w[2].startswith("-v") for w in words):
                return True
            if cmd[2] == "cp" and any(w[2] == "-s" or w[2].startswith("--symbolic") or
                                      re.fullmatch(r"-[A-Za-z]*s[A-Za-z]*", w[2]) for w in words):
                return True
        return False

    def _names(self, shape):
        """NAME -> (value, line) for a NAME set once in the call, by a bare `NAME=<literal>` line
        that is not a continuation, and named nowhere else."""
        bare, seen = {}, {}
        for _, text, raw in shape.words:
            m = NAME_EQ.match(raw)
            if m:
                seen[m.group(1)] = seen.get(m.group(1), 0) + 1
            if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", text):
                seen[text] = seen.get(text, 0) + 1
        for cmds in shape.lines:
            if not cmds or len(cmds) != 1 or cmds[0]["prev"] != "start" or cmds[0]["next"] != "\n":
                continue
            items = cmds[0]["items"]
            if len(items) != 1 or items[0][0] != "word" or items[0][2] != items[0][3]:
                continue
            m = NAME_EQ.match(items[0][3])
            if not m or m.group(2):
                continue
            name, value = m.group(1), items[0][3][m.end():]
            if name in SPECIAL_NAMES or name.startswith(("BASH", "EPOCH")):
                continue
            if value == "" or LITERAL.match(value):
                bare[name] = (value, cmds[0]["line"])
        return {k: v for k, v in bare.items() if seen.get(k) == 1}

    def _literal(self, text, raw, names, line):
        """The cd target as bash sees it, if it is literal: [A-Za-z0-9._/+-] only, after each
        `$NAME` is replaced from `names` (set on an earlier line). No quotes: `'$S'` is no
        expansion and `$"S"` is the string S."""
        if "'" in raw or '"' in raw:
            return None

        def sub(m):
            got = names.get(m.group(1))
            return got[0] if got and got[1] < line else "\0"
        out = re.sub(r"\$([A-Za-z_][A-Za-z0-9_]*)", sub, text)
        if LITERAL.match(out) and not out.startswith(("-", "+")):   # -, +1: OLDPWD, dir stack
            return out
        return None

    def _simulate(self, shape):
        if self._refused(shape):
            return None
        jail, names = self.jail, self._names(shape)
        state, chain, cwds = self.cwd, None, {}
        for cmds in shape.lines:
            if chain is not None and cmds is not None:
                chain, state = None, None      # a chain never outlives its line
            for c in cmds or ():
                if chain is not None and c["prev"] not in ("&&", "|"):
                    chain, state = None, None
                here = chain if chain is not None else state
                moved, arg_next = False, False
                for it in c["items"]:
                    cwds[it[1]] = here if arg_next or not moved else None
                    if it[0] == "redir":
                        cwds[it[1] + 1] = None if moved else here
                        arg_next = False
                        continue
                    if arg_next:
                        arg_next = False
                    elif CHDIR_OPTION.match(it[2]):
                        # `-C dir`, `--directory=dir`: dir is read from `here`, what follows is not
                        cwds[it[1]] = here
                        moved = True
                        arg_next = CHDIR_OPTION.fullmatch(it[2]) is not None
                words = [it for it in c["items"] if it[0] == "word"]
                is_cd = [w for w in words if w[2] in CD_WORDS]
                if not is_cd:
                    continue
                first = c["items"][0]
                ok_form = (first[0] == "word" and first[2] in CD_WORDS and len(is_cd) == 1
                           and len(c["items"]) == 2 and c["items"][1][0] == "word"
                           and c["prev"] in ("start", ";") and c["next"] in ("\n", ";", "&&", "||"))
                d = self._literal(c["items"][1][2], c["items"][1][3], names, c["line"]) \
                    if ok_form else None
                if chain is not None or d is None:
                    chain, state = None, None
                    continue
                if os.path.isabs(d):
                    target = norm(d)
                elif state is not None:
                    target = norm(os.path.join(state, d))
                else:
                    continue                    # a relative cd from an unknown cwd: still unknown
                if not phys_ok(jail, target):
                    state = None
                elif os.path.isdir(target):
                    state = target
                elif not os.path.lexists(target) and c["next"] == "&&":
                    chain = target              # trusted only for the rest of its && chain
                else:
                    state = None
        if chain is not None:
            state = None
        return cwds, state


def rule_c_bodies(shape):
    """The heredoc bodies whose data-body findings rule (c) clears — a body a plain `cat` or `tee`
    writes to a file, that nothing can turn into code — as {k: the files it is written to}."""
    if not shape.ok or shape.flags & {"group", "subst"}:
        return {}
    for _, text, raw in shape.words:
        m = NAME_EQ.match(raw)
        if m and (m.group(1) in C_NAMES or m.group(1).startswith("LD_")):
            return {}
    for c in shape.commands():
        cmd = command_word(c)
        if cmd is not None and (not COMMAND_WORD.match(cmd[2]) or cmd[2] in C_REFUSE):
            return {}
    by_op = {}
    for c in shape.commands():
        for it in c["items"]:
            if it[0] == "redir" and it[2] == "<<":
                by_op[it[1]] = c
    cleared = {}
    for k, (ln_no, op_index, quoted) in enumerate(shape.ops):
        text, shell, body_quoted = shape.bodies[k]
        c = by_op.get(op_index)
        if c is None or shell or quoted != body_quoted:
            continue
        if not quoted and any(x in text for x in ("`", "$(", "${", "$[")):
            continue
        if c["next"] == "|":
            continue
        items = c["items"]
        first = items[0]
        if first[0] != "word" or first[2] != first[3] or first[2] not in ("cat", "tee"):
            continue
        redirs = [it for it in items[1:] if it[0] == "redir"]
        words = [it for it in items[1:] if it[0] == "word"]
        outs = [r for r in redirs if r[2] in (">", ">>")]
        if len(redirs) != 2 or len(outs) != 1 or not any(r[1] == op_index for r in redirs):
            continue
        if first[2] == "cat":
            if words:
                continue
        else:
            if words and words[0][2] == "-a":
                words = words[1:]
            if not words or any(w[2].startswith("-") or w[2] == "" or w[2].isdigit() for w in words):
                continue
        cleared[k] = [w[2] for w in words] + [outs[0][3][0]]
    return cleared


def runs_file(text, path):
    """True if some command in `text` may run the file `path` (a runner naming it, or the file as
    the command itself). Crude on purpose: it splits on every separator and bracket."""
    base = os.path.basename(path.rstrip("/"))
    if not base or path.startswith("/dev/") or base not in text:
        return False
    for seg in re.split(r"[\n;&|()`{}]|\$\(", text):
        if base not in seg:
            continue
        words = seg.split()
        while words and NAME_EQ.match(words[0]):
            words.pop(0)
        if not words:
            continue
        cmd = words[0]
        if os.path.basename(cmd.strip("'\"")) in RUNNERS or \
                cmd[0] not in "'\"" and "/" in cmd and cmd.endswith(base):
            return True
    return False


def rule_b(jail, origin, cwd):
    """A `//` part right after `scheme:` is a path below a dir named `scheme:`; it clears when that
    path, read from the known rule-(a) cwd, cannot leave it."""
    part, pi = origin.get("part"), origin.get("part_index")
    if cwd is None or not part or not part.startswith("//") or not pi:
        return False
    caps = re.split(r"([=:])", origin["token"])
    if 2 * pi >= len(caps) or caps[2 * pi] != part or caps[2 * pi - 1] != ":":
        return False
    scheme = caps[2 * pi - 2]
    if not SCHEME.match(scheme) or scheme.lower() == "file":
        return False
    authority = part[2:].split("/", 1)[0]
    if authority in ("", ".", ".."):
        return False
    rel = norm(scheme + ":" + part)
    return not rel.startswith("..") and lands_ok(jail, cwd, scheme + ":" + part)


def clearing_rule(jail, kind, origin, a_cwds, c_bodies, op_cwd, rules):
    """The rule that clears one engine finding of a Bash call, or None."""
    if not origin:
        return None
    src = origin.get("source")
    if "a" in rules and a_cwds is not None and kind == "escape" and origin.get("dotdot") \
            and src in ("token", "cd") and origin.get("index") is not None:
        cwd = a_cwds.get(origin["index"])
        pattern = LITERAL_TOKEN if src == "token" else LITERAL
        if cwd is not None and pattern.match(origin["token"]) and lands_ok(jail, cwd, origin["part"]):
            return "a"
    if "b" in rules and kind == "escape" and a_cwds is not None:
        if src == "token":
            cwd = a_cwds.get(origin.get("index"))
        elif src == "data-body":
            cwd = op_cwd(origin.get("body"))
        else:
            cwd = None
        if rule_b(jail, origin, cwd):
            return "b"
    if "c" in rules and src == "data-body" and origin.get("body") in c_bodies:
        return "c"
    return None


def collect(jail, lines, rules):
    """Run the engine over the tool calls, then the clearance pass. Returns (count, found): each
    found entry is (call, tool name, kind, detail, clearing rule or None, origin or None)."""
    cwd = jail.clone
    rule_a = RuleA(jail)
    found = []
    count = 0
    commands = []        # (call, Bash command): where a file a body was written to may be run
    writes = {}          # (call, body k) -> the files rule (c) says body k is written to
    for block in tool_uses(lines):
        count += 1
        name = block.get("name", "?")
        inp = block.get("input") or {}
        if not isinstance(inp, dict):
            inp = {}
        if block.get("type") == "server_tool_use" or WEB_TOOL_RE.search(name):
            found.append((count, name, "web", f"web tool used: {json.dumps(inp)[:200]}", None, None))
            continue
        if name == "Bash":
            command = str(inp.get("command", ""))
            v, cwd = audit_bash(jail, command, cwd)
            if not jail.inside(cwd):
                cwd = jail.clone  # Claude Code puts the shell back in the project dir
            shape = Shape(command)
            a_cwds = rule_a.call(shape)
            c_bodies = rule_c_bodies(shape)

            def op_cwd(k, shape=shape, a_cwds=a_cwds):
                if a_cwds is None or k is None or k >= len(shape.ops):
                    return None
                return a_cwds.get(shape.ops[k][1])
            for k, files in c_bodies.items():
                writes[(count, k)] = files
            commands.append((count, command))
            found += [(count, name, k, d + f" | {command[:200]!r}",
                       clearing_rule(jail, k, o, a_cwds, set(c_bodies), op_cwd, rules), o)
                      for k, d, o in v]
        elif name in FILE_TOOLS or any(k in inp for k in PATH_KEYS):
            found += [(count, name, k, d, None, None) for k, d in audit_file_tool(jail, name, inp)]
    # rule (c) holds only while the written file stays data: withdraw it if a command in its own
    # call (bodies included) or in a later call may run that file
    for i, (n, name, kind, detail, rule, origin) in enumerate(found):
        if rule != "c":
            continue
        files = writes[(n, origin["body"])]
        if any(runs_file(t, f) for f in files for m, t in commands if m >= n):
            found[i] = (n, name, kind, detail, None, origin)
    return count, found


def main(argv):
    explain = "--explain" in argv[1:]
    argv = [argv[0]] + [a for a in argv[1:] if a != "--explain"]
    try:
        rules = enabled_rules()
    except ValueError as e:
        print(f"audit: {e}", file=sys.stderr)
        return 2
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
    count, found = collect(jail, lines, rules)

    note = f" ({bad} non-JSON line(s) skipped)" if bad else ""
    kept = [f for f in found if f[4] is None]
    for n, name, kind, detail, rule, _ in found:
        line = f"VIOLATION [{kind}] call #{n} {name}: {detail}"
        if rule is None:
            print(line)
        elif explain:
            print(f"cleared ({rule}): {line}")
    if kept:
        print(f"audit: {len(kept)} violation(s) in {count} tool call(s){note} — clone {jail.clone}")
        return 1
    print(f"audit: clean — {count} tool call(s) checked{note}, clone {jail.clone}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
