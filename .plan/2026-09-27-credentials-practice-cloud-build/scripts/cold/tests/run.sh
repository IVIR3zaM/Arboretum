#!/usr/bin/env bash
# cold/tests/run.sh — self-test for audit.py. Feeds it synthetic stream-json transcripts against a
# throwaway clone dir: each violation kind (a file tool outside the clone, an outside path in Bash,
# a `cd ..` escape, a web tool) must exit 1 and name the violation; a clean transcript, including
# the things a real run does legitimately (relative `..` inside the clone, /dev/null redirects, route
# strings that look like paths, toolchain caches), must exit 0.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AUDIT="$HERE/../audit.py"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CLONE="$TMP/clone"
mkdir -p "$CLONE/src"
echo '{}' > "$CLONE/package.json"

failures=0
fail() { echo "cold test FAIL: $1" >&2; failures=$((failures + 1)); }

# tool_use <name> <input-json> — one assistant line of a stream-json transcript.
tool_use() {
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t%s","name":"%s","input":%s}]}}\n' \
    "$RANDOM" "$1" "$2"
}

header() {
  printf '{"type":"system","subtype":"init","cwd":"%s","model":"claude-opus-test"}\n' "$CLONE"
}

# expect <case> <want-exit> <want-pattern-in-output> — reads the transcript from $TMP/<case>.jsonl.
expect() {
  local name=$1 want=$2 pattern=$3 out rc
  out=$(python3 "$AUDIT" "$TMP/$name.jsonl" "$CLONE" 2>&1)
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    fail "$name: audit exited $rc, want $want. Output:
$out"
    return
  fi
  if [ -n "$pattern" ] && ! grep -qE -- "$pattern" <<<"$out"; then
    fail "$name: output does not match /$pattern/. Output:
$out"
    return
  fi
  echo "ok  $name (exit $rc)"
}

# (1) a file tool whose path is outside the clone
{ header; tool_use Read "{\"file_path\":\"$CLONE/package.json\"}"; tool_use Read '{"file_path":"/etc/passwd"}'; } > "$TMP/outside-read.jsonl"
expect outside-read 1 '/etc/passwd'

# (2) a Bash command naming a path outside the clone
{ header; tool_use Bash '{"command":"ls src && cat /etc/hostname"}'; } > "$TMP/outside-bash.jsonl"
expect outside-bash 1 '/etc/hostname'

# (3) a Bash command escaping the clone with ..
{ header; tool_use Bash '{"command":"cd .. && ls"}'; } > "$TMP/cd-escape.jsonl"
expect cd-escape 1 '\.\.'

# (3b) a relative .. path that leaves the clone, without cd
{ header; tool_use Bash '{"command":"cat ../../secrets.txt"}'; } > "$TMP/dotdot-escape.jsonl"
expect dotdot-escape 1 '\.\./\.\./secrets\.txt'

# (4) any web tool
{ header; tool_use WebFetch '{"url":"https://example.com","prompt":"read it"}'; } > "$TMP/webfetch.jsonl"
expect webfetch 1 'WebFetch'

{ header; tool_use WebSearch '{"query":"how to fix"}'; } > "$TMP/websearch.jsonl"
expect websearch 1 'WebSearch'

# (5) a clean transcript: everything stays inside the clone or in an allowed toolchain dir
{
  header
  tool_use Read "{\"file_path\":\"$CLONE/package.json\"}"
  tool_use Glob '{"pattern":"src/**/*.ts"}'
  tool_use Grep "{\"pattern\":\"cutoff\",\"path\":\"$CLONE/src\"}"
  tool_use Edit "{\"file_path\":\"$CLONE/src/a.ts\",\"old_string\":\"a\",\"new_string\":\"b\"}"
  tool_use Write '{"file_path":"src/b.ts","content":"export const x = \"/etc/not-a-read\";"}'
  tool_use Bash '{"command":"cd src && cat ../package.json 2>/dev/null | head -5; cd .."}'
  tool_use Bash '{"command":"grep -rn \"/api/v1/users\" src || true"}'
  tool_use Bash "{\"command\":\"ls ~/.cargo/registry >/dev/null; $HOME/.cargo/bin/cargo --version\"}"
  tool_use Bash "{\"command\":\"git -C $CLONE status --short && git diff HEAD -- src\"}"
  tool_use TodoWrite '{"todos":[]}'
} > "$TMP/clean.jsonl"
expect clean 0 'clean'

# bash_cmd <command> — the input JSON of a Bash tool call (newlines and quotes escaped).
bash_cmd() { python3 -c 'import json, sys; print(json.dumps({"command": sys.argv[1]}))' "$1"; }

# (6) heredoc bodies fed to a non-shell are data: a `~/` in them (Dart integer division) is not $HOME
{ header; tool_use Bash "$(bash_cmd $'cat > a.dart <<\'EOF\'\nfinal s = ms ~/ 1000;\nEOF')"; } > "$TMP/heredoc-dart-tilde.jsonl"
expect heredoc-dart-tilde 0 'clean'

{ header; tool_use Bash "$(bash_cmd $'python3 - <<\'EOF\'\ns = "x ~/ 1000"\nEOF')"; } > "$TMP/heredoc-python-tilde.jsonl"
expect heredoc-python-tilde 0 'clean'

# the same body behind an unbalanced quote (a comment's apostrophe), which is what tripped real runs
{ header; tool_use Bash "$(bash_cmd $'python3 - <<\'EOF\'\n# it\'s the seconds\ns = "x ~/ 1000"\nEOF')"; } > "$TMP/heredoc-python-tilde-apostrophe.jsonl"
expect heredoc-python-tilde-apostrophe 0 'clean'

# (7) strictness kept: absolute paths in a data body, a shell-fed body, `~` on the command line,
# and the CLI's own spill and scratch dirs outside the clone
{ header; tool_use Bash "$(bash_cmd $'python3 - <<\'EOF\'\nopen("/etc/hostname")\nEOF')"; } > "$TMP/heredoc-python-abs.jsonl"
expect heredoc-python-abs 1 '/etc/hostname'

{ header; tool_use Bash "$(bash_cmd $'bash <<\'EOF\'\ncat ~/.ssh/config\nEOF')"; } > "$TMP/heredoc-bash-home.jsonl"
expect heredoc-bash-home 1 "$HOME/\\.ssh/config"

{ header; tool_use Bash "$(bash_cmd 'ls ~/')"; } > "$TMP/cmdline-ls-home.jsonl"
expect cmdline-ls-home 1 "outside path $HOME/?( |$)"

{ header; tool_use Bash "$(bash_cmd 'cat ~/.ssh/config')"; } > "$TMP/cmdline-cat-home.jsonl"
expect cmdline-cat-home 1 "$HOME/\\.ssh/config"

{ header; tool_use Read "{\"file_path\":\"$HOME/.claude/projects/x/tool-results/y.txt\"}"; } > "$TMP/read-cli-spill.jsonl"
expect read-cli-spill 1 '\.claude/projects/x/tool-results/y\.txt'

{ header; tool_use Bash "$(bash_cmd 'cat /tmp/claude-0/x/scratchpad/f')"; } > "$TMP/bash-cli-scratchpad.jsonl"
expect bash-cli-scratchpad 1 '/tmp/claude-0/x/scratchpad/f'

# (8) heredoc edge cases: a body fed to an interpreter still gets the $HOME and .. checks; a body
# piped into a shell is shell; an unquoted body's $(...) runs, so it is shell; a heredoc in $(...)
# is still data
{ header; tool_use Bash "$(bash_cmd $'python3 - <<\'EOF\'\nsee $HOME/.netrc and ../../up.txt\nEOF')"; } > "$TMP/heredoc-data-home-dotdot.jsonl"
expect heredoc-data-home-dotdot 1 "$HOME/\\.netrc"
expect heredoc-data-home-dotdot 1 '\.\./\.\./up\.txt'

{ header; tool_use Bash "$(bash_cmd $'cat <<\'EOF\' | sh\ncat ~/.ssh/config\nEOF')"; } > "$TMP/heredoc-pipe-shell.jsonl"
expect heredoc-pipe-shell 1 "$HOME/\\.ssh/config"

{ header; tool_use Bash "$(bash_cmd $'cat > x.txt <<EOF\nkey: $(cat ~/.ssh/id_rsa)\nEOF')"; } > "$TMP/heredoc-unquoted-subst.jsonl"
expect heredoc-unquoted-subst 1 "$HOME/\\.ssh/id_rsa"

{ header; tool_use Bash "$(bash_cmd $'git commit -q -m "$(cat <<\'EOF\'\nfix: it\'s ms ~/ 1000 now\nEOF\n)"')"; } > "$TMP/heredoc-in-subst.jsonl"
expect heredoc-in-subst 0 'clean'

# (9) newline separators, URL authorities, and cat/tee-to-file heredoc bodies (D23)
# (a) an unquoted newline is a command separator: the `cd` on the next line moves the cwd
{ header; tool_use Bash "$(bash_cmd $'X=1\ncd backend && ls ../app')"; } > "$TMP/newline-cd-inside.jsonl"
expect newline-cd-inside 0 'clean'

{ header; tool_use Bash "$(bash_cmd $'echo x\ncd ..\nls')"; } > "$TMP/newline-cd-escape.jsonl"
expect newline-cd-escape 1 '\.\.'

{ header; tool_use Bash "$(bash_cmd $'S=/x\ncat $S/../../etc/passwd')"; } > "$TMP/newline-var-dotdot.jsonl"
expect newline-var-dotdot 1 '\$S/\.\./\.\./etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'X=1\ncd backend\ncat ../../x')"; } > "$TMP/newline-cd-then-escape.jsonl"
expect newline-cd-then-escape 1 '\.\./\.\./x'

# a newline inside quotes, or after a backslash, is not a separator
{ header; tool_use Bash "$(bash_cmd $'echo "a\ncd sub" && cat ../x')"; } > "$TMP/newline-in-quotes.jsonl"
expect newline-in-quotes 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo a \\\ncd sub && cat ../x')"; } > "$TMP/newline-continuation.jsonl"
expect newline-continuation 1 '\.\./x'

# (b) a URL authority left after the scheme's `:` is not a path on its own
{ header; tool_use Bash "$(bash_cmd 'curl -s https://h.example/../../x')"; } > "$TMP/url-authority.jsonl"
expect url-authority 0 'clean'

{ header; tool_use Bash "$(bash_cmd 'cat /etc/../etc/passwd')"; } > "$TMP/cmdline-abs-dotdot.jsonl"
expect cmdline-abs-dotdot 1 '/etc/\.\./etc/passwd'

# (c) a cat/tee body written only to a file is audited like Write content
{ header; tool_use Bash "$(bash_cmd $'cat > t.rs <<\'EOF\'\nlet root = "/tmp/does-not-exist-root";\nlet u = "https://h.example/../../etc/passwd";\nprintln!("{}", format!("{} / {}", a, b));\nEOF')"; } > "$TMP/heredoc-cat-file-rust.jsonl"
expect heredoc-cat-file-rust 0 'clean'

{ header; tool_use Bash "$(bash_cmd $'cat >> t.rs <<\'EOF\'\n// reads /etc/passwd\nEOF')"; } > "$TMP/heredoc-cat-append.jsonl"
expect heredoc-cat-append 0 'clean'

{ header; tool_use Bash "$(bash_cmd $'tee t.rs <<\'EOF\' >/dev/null\n// reads /etc/passwd\nEOF')"; } > "$TMP/heredoc-tee-file.jsonl"
expect heredoc-tee-file 0 'clean'

# ... but its target path is still checked, an unquoted body's $(...) is still shell, and a body to
# stdout, piped onward or fed to a shell keeps every check
{ header; tool_use Bash "$(bash_cmd $'cat > $HOME/x.txt <<\'EOF\'\nhi\nEOF')"; } > "$TMP/heredoc-cat-target-home.jsonl"
expect heredoc-cat-target-home 1 "$HOME/x\\.txt"

{ header; tool_use Bash "$(bash_cmd $'cat > ../../x.txt <<\'EOF\'\nhi\nEOF')"; } > "$TMP/heredoc-cat-target-dotdot.jsonl"
expect heredoc-cat-target-dotdot 1 '\.\./\.\./x\.txt'

{ header; tool_use Bash "$(bash_cmd $'cat > x.txt <<EOF\n$(cat /etc/passwd)\nEOF')"; } > "$TMP/heredoc-cat-file-subst.jsonl"
expect heredoc-cat-file-subst 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'cat <<\'EOF\'\n/etc/passwd\nEOF')"; } > "$TMP/heredoc-cat-stdout.jsonl"
expect heredoc-cat-stdout 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'cat > x.txt <<\'EOF\' | python3 -\nopen("/etc/passwd")\nEOF')"; } > "$TMP/heredoc-cat-file-piped.jsonl"
expect heredoc-cat-file-piped 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'tee t.rs <<\'EOF\' | python3 -\nopen("/etc/passwd")\nEOF')"; } > "$TMP/heredoc-tee-piped.jsonl"
expect heredoc-tee-piped 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'cat 2>/dev/null <<\'EOF\'\n/etc/passwd\nEOF')"; } > "$TMP/heredoc-cat-stderr-only.jsonl"
expect heredoc-cat-stderr-only 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'python3 $(echo -) cat > x.txt <<\'EOF\'\nopen("/etc/passwd")\nEOF')"; } > "$TMP/heredoc-cat-after-subst.jsonl"
expect heredoc-cat-after-subst 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'python3 \\\ncat > x.txt <<\'EOF\'\nopen("/etc/passwd")\nEOF')"; } > "$TMP/heredoc-cat-continued.jsonl"
expect heredoc-cat-continued 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'cat > x.sh <<\'EOF\' && bash x.sh\ncat /etc/passwd\nEOF')"; } > "$TMP/heredoc-cat-file-then-shell.jsonl"
expect heredoc-cat-file-then-shell 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'tee t.rs <<\'EOF\'\n/etc/passwd\nEOF')"; } > "$TMP/heredoc-tee-stdout.jsonl"
expect heredoc-tee-stdout 1 '/etc/passwd'

{ header; tool_use Bash "$(bash_cmd $'echo "$(cat > x.txt <<\'EOF\'\n/etc/passwd\nEOF\n)"')"; } > "$TMP/heredoc-cat-file-in-subst.jsonl"
expect heredoc-cat-file-in-subst 1 '/etc/passwd'

# a newline inside ( ) (here an array) is left alone, so its `cd sub` does not move the cwd
{ header; tool_use Bash "$(bash_cmd $'a=(\nx\ncd sub\n)\ncat ../y')"; } > "$TMP/newline-in-array.jsonl"
expect newline-in-array 1 '\.\./y'

# a `scheme://` word is still resolved as a whole, and a token that starts with // keeps its check
{ header; tool_use Bash "$(bash_cmd 'cat a://../../etc/passwd')"; } > "$TMP/url-word-escape.jsonl"
expect url-word-escape 1 'a://\.\./\.\./etc/passwd'

{ header; tool_use Bash "$(bash_cmd 'cat //../etc/passwd')"; } > "$TMP/double-slash-dotdot.jsonl"
expect double-slash-dotdot 1 '//\.\./etc/passwd'

# (11) quoting that hides a newline from bash (N23 try 2). Each of these really reads ../x (or
# /etc/passwd) from the clone in bash; a newline the audit wrongly splits on would let a `cd sub`
# inside a string move the audit's cwd, so every one must still exit 1.
# ANSI-C $'...': \' does not end the string (the try-1 verifier's repro, both forms)
{ header; tool_use Bash "$(bash_cmd $'echo $\'a\\\'\ncd sub\n\' ; cat ../x')"; } > "$TMP/ansi-escaped-quote.jsonl"
expect ansi-escaped-quote 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'X=$\'\\\'\ncd sub\n\'; cat ../x')"; } > "$TMP/ansi-escaped-quote-assign.jsonl"
expect ansi-escaped-quote-assign 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo $\'\\\' ; cd sub ; \' ; cat ../x')"; } > "$TMP/ansi-escaped-quote-one-line.jsonl"
expect ansi-escaped-quote-one-line 1 '\.\./x'

# a `<<` inside $'...' is not a heredoc, so the next line is shell, not a cat-to-file body
{ header; tool_use Bash "$(bash_cmd $'cat $\'\\\'>x <<EOF\n\'; cat /etc/passwd\nEOF')"; } > "$TMP/ansi-fake-heredoc.jsonl"
expect ansi-fake-heredoc 1 '/etc/passwd'

# $'...' is read with its escapes: an escaped backslash does not escape the closing quote, and the
# string's value is what gets checked
{ header; tool_use Bash "$(bash_cmd $'echo $\'a\\\\\'\ncd sub\ncat ../x')"; } > "$TMP/ansi-escaped-backslash.jsonl"
expect ansi-escaped-backslash 0 'clean'

{ header; tool_use Bash "$(bash_cmd $'cat $\'/etc/pass\\x77d\'')"; } > "$TMP/ansi-value.jsonl"
expect ansi-value 1 '/etc/passwd'

# $"..." is a double-quoted string
{ header; tool_use Bash "$(bash_cmd $'echo $"a\ncd sub" && cat ../x')"; } > "$TMP/dollar-dq.jsonl"
expect dollar-dq 1 '\.\./x'

# a backslash-newline is a line continuation, in a double-quoted string too, and bash removes it
{ header; tool_use Bash "$(bash_cmd $'echo "a\\\ncd sub" && cat ../x')"; } > "$TMP/dq-continuation.jsonl"
expect dq-continuation 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'cd \\\n.. && cat x')"; } > "$TMP/continuation-cd.jsonl"
expect continuation-cd 1 '\.\.'

{ header; tool_use Bash "$(bash_cmd $'cat /et\\\nc/passwd')"; } > "$TMP/continuation-path.jsonl"
expect continuation-path 1 '/etc/passwd'

# comments: `#` after a subshell's `)` starts one; `#` glued to a word by a continuation does not
{ header; tool_use Bash "$(bash_cmd $'(echo a)#it\'s\n\'\ncd sub\n\'; cat ../x')"; } > "$TMP/comment-after-paren.jsonl"
expect comment-after-paren 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo a\\\n#\'\ncd sub\n\'; cat ../x')"; } > "$TMP/comment-after-continuation.jsonl"
expect comment-after-continuation 1 '\.\./x'

# backticks end at the first unescaped backtick, even one inside quotes
{ header; tool_use Bash "$(bash_cmd $'echo `echo \'`\'\ncd sub\n\'; cat ../x #\'')"; } > "$TMP/backtick-quote.jsonl"
expect backtick-quote 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo `echo \'`\'X`\ncd sub\n\'; cat ../x #\'')"; } > "$TMP/backtick-quote-2.jsonl"
expect backtick-quote-2 1 '\.\./x'

# newlines inside $( ), ( ) and ${ } are not top-level separators; a case pattern's `)` inside them
# is not their end
{ header; tool_use Bash "$(bash_cmd $'echo "$(case x in a) echo "\ncd sub\n";; esac)"; cat ../x')"; } > "$TMP/subst-case.jsonl"
expect subst-case 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'(case x in a) echo x\ncd sub\n;; esac); cat ../x')"; } > "$TMP/subshell-case.jsonl"
expect subshell-case 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo $(\ncd sub\n); cat ../x')"; } > "$TMP/subst-newline.jsonl"
expect subst-newline 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo ${x:-\'\ncd sub\n\'}; cat ../x')"; } > "$TMP/brace-sq.jsonl"
expect brace-sq 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo "${x:-\'"\'}"; echo \'\ncd sub\n\'; cat ../x')"; } > "$TMP/brace-dq-sq.jsonl"
expect brace-dq-sq 1 '\.\./x'

{ header; tool_use Bash "$(bash_cmd $'echo ${x:-a\ncd sub\n}; cat ../x')"; } > "$TMP/brace-newline.jsonl"
expect brace-newline 1 '\.\./x'

# a heredoc body's newlines are the body's: a `cd sub` line in it is data, not a separator
{ header; tool_use Bash "$(bash_cmd $'cat > t.txt <<\'EOF\'\ncd sub\nEOF\ncat ../x')"; } > "$TMP/heredoc-body-cd.jsonl"
expect heredoc-body-cd 1 '\.\./x'

# (10) replays of the three voided turn-09 attempts of N17's train run (all false positives). The
# fixtures are the recorded transcripts with the clone path replaced by @@CLONE@@.
for k in 1 2 3; do
  sed "s#@@CLONE@@#$CLONE#g" "$HERE/fixtures/n17-turn-09-void-$k.jsonl" > "$TMP/replay-n17-turn-09-void-$k.jsonl"
  expect "replay-n17-turn-09-void-$k" 0 'clean'
done

if [ "$failures" -gt 0 ]; then
  echo "cold tests: $failures failure(s)" >&2
  exit 1
fi
echo "cold tests: all passed"
