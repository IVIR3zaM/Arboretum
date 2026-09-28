#!/usr/bin/env python3
"""showturn.py <turn transcript.jsonl> — list the turn's tool calls and print its final reply."""
import json, sys
n = 0
for l in open(sys.argv[1]):
    o = json.loads(l)
    if o.get('type') == 'assistant':
        for c in o['message']['content']:
            if c.get('type') == 'tool_use':
                n += 1
                i = c['input']
                print(n, c['name'], (i.get('command') or i.get('file_path') or i.get('pattern') or str(i))[:200].replace('\n', ' '))
    if o.get('type') == 'result':
        print('--- result (duration_ms=%s, num_turns=%s)' % (o.get('duration_ms'), o.get('num_turns')))
        print(o.get('result'))
