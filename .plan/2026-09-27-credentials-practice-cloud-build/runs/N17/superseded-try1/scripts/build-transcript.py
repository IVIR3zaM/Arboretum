#!/usr/bin/env python3
"""build-transcript.py — the N17 train run's ordered transcript (train/transcript.md).

Per turn, in order: the learner's prompt (verbatim), the assistant's final reply (verbatim, from the
turn's stream-json slice), its tool-call count and jail audit line; then any outcome-checker
checkpoint taken after that turn (unit summary + grade axes, read from the captured files), any
staging event (staging.log), and the trainer's note. Voided attempts are listed where they happened.
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
T = os.path.join(HERE, 'train')
CK = os.path.join(T, 'checkpoints')

def result_and_calls(path):
    res, calls = None, 0
    for line in open(path, encoding='utf-8'):
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get('type') == 'assistant':
            calls += sum(1 for c in o['message']['content'] if c.get('type') == 'tool_use')
        if o.get('type') == 'result':
            res = o.get('result')
    return res, calls

def quote(text):
    return '\n'.join(('> ' + l) if l else '>' for l in text.rstrip().splitlines()) + '\n'

def first(path):
    with open(path, encoding='utf-8') as f:
        return f.readline().rstrip('\n')

def checkpoint(name):
    d = os.path.join(CK, name)
    unit = subprocess.run(['bash', os.path.join(HERE, 'sumunit.sh'), os.path.join(d, 'unit.txt')],
                          capture_output=True, text=True).stdout.strip()
    grade = open(os.path.join(d, 'grade.txt'), encoding='utf-8').read()
    summ = grade.split(' summary (worst-case; every axis must pass)')[-1]
    axes = [l for l in summ.splitlines() if l.startswith('axis ') or l.startswith('worst-case:')]
    date = re.search(r'^date: (.*)$', grade, re.M)
    return unit, axes, date.group(1) if date else ''

ck_after = {}
for name in sorted(os.listdir(CK)):
    m = re.match(r'(\d+)-', name)
    if not m or not os.path.isdir(os.path.join(CK, name)):
        continue
    ck_after.setdefault(int(m.group(1)), []).append(name)

staging = {}
for line in open(os.path.join(T, 'staging.log'), encoding='utf-8'):
    m = re.search(r'checkpoints/(\d+)-', line)
    if m:
        staging.setdefault(int(m.group(1)), []).append(line.strip())

turns = sorted(int(d[5:]) for d in os.listdir(T) if re.fullmatch(r'turn-\d+', d))
voids = sorted(d for d in os.listdir(T) if re.fullmatch(r'turn-\d+-void-\d+', d))

out = []
w = out.append
w('# Ordered transcript — credentials, TRAIN mode (calibration run)\n')
w('Learner prompts and trainer notes written by the operator, who had golden access (AGENTS.md rule 10): '
  'this is a **calibration run**, not a learner grade. Assistant: a cold `claude -p --model opus` session '
  'in `/tmp/cold-N17-train` (outside the repo), resumed turn after turn. Checkpoints are the outcome '
  "checker's runs of practice.json's commands.install/test/grade on a throwaway copy; the assistant never "
  'saw a score. Verbatim sources: `train/turn-NN/` (prompt.txt, transcript.jsonl, audit.txt, diff.patch), '
  '`train/checkpoints/*/` (unit.txt, grade.txt), `train/trainer/`, `train/staging.log`.\n')

def emit_ck(n):
    for name in ck_after.get(n, []):
        unit, axes, date = checkpoint(name)
        w(f'\n### Checkpoint `{name}` (outcome checker, {date})\n')
        w('```')
        w(unit)
        w('\n'.join(axes))
        w('```')
    for s in staging.get(n, []):
        w(f'\n**Staging:** {s}\n')

emit_ck(0)
for n in turns:
    d = os.path.join(T, f'turn-{n:02d}')
    for v in voids:
        if int(v[5:7]) == n:
            vr, vc = result_and_calls(os.path.join(T, v, 'transcript.jsonl'))
            w(f'\n## Turn {n} — voided attempt `{v}`\n')
            w(f'Same prompt. Jail audit: `{first(os.path.join(T, v, "audit.txt"))}` ({vc} tool calls). '
              'The attempt was voided, the clone and the CLI session store rolled back to their pre-turn '
              'state (`session-store-before-rollback.jsonl` keeps the discarded store), and the turn re-run '
              'from the same prompt. Its reply is not part of the session the learner saw.\n')
    res, calls = result_and_calls(os.path.join(d, 'transcript.jsonl'))
    meta = open(os.path.join(d, 'meta.env'), encoding='utf-8').read()
    date = re.search(r'^DATE=(.*)$', meta, re.M).group(1)
    w(f'\n## Turn {n} ({date})\n')
    w('### Learner prompt\n')
    w(quote(open(os.path.join(d, 'prompt.txt'), encoding='utf-8').read()))
    w(f'### Assistant — final reply ({calls} tool calls; `{first(os.path.join(d, "audit.txt"))}`)\n')
    w(quote(res or '(no result)'))
    emit_ck(n)
    tn = os.path.join(T, 'trainer', f'after-turn-{n:02d}.md')
    if os.path.exists(tn):
        w('\n### Trainer note\n')
        w(quote(open(tn, encoding='utf-8').read()))
emit_ck(99)
sys.stdout.write('\n'.join(out) + '\n')
