#!/usr/bin/env python3
"""Rebuilds the files a reboot wiped from this session's scratchpad (/private/tmp is emptied on restart) by replaying
every Write and Edit made to them, in time order, from the session's own transcript and every workflow agent's.
Restores them in place (so live prompts that name these paths work again) and copies the text files into the thuyvan
worktree (docs/thuyvan/plan/, tools/thuyvan/bin/) so a reboot cannot lose them again."""
import glob
import json
import os
import shutil

SID = 'd8726f05-a14a-44ac-97c9-351a2e11c5c5'
SCR = f'/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/{SID}/scratchpad/'
PROJ = os.path.expanduser('~/.claude/projects/')
LANE = '/Users/kiwimango/Downloads/Frontier/.claude/worktrees/thuyvan/'

files = []
for key in os.listdir(PROJ):
    base = PROJ + key + '/'
    files += glob.glob(base + SID + '.jsonl')
    files += glob.glob(base + SID + '/subagents/**/*.jsonl', recursive=True)

ops = []
for f in files:
    for line in open(f, errors='replace'):
        try:
            d = json.loads(line)
        except Exception:
            continue
        ts = d.get('timestamp', '')
        c = (d.get('message') or {}).get('content')
        if not isinstance(c, list):
            continue
        for x in c:
            if x.get('type') != 'tool_use' or x.get('name') not in ('Write', 'Edit'):
                continue
            inp = x.get('input') or {}
            p = inp.get('file_path', '')
            if p.startswith(SCR):
                ops.append((ts, x['name'], p, inp))

ops.sort(key=lambda o: o[0])
state = {}
missed = []
for ts, name, p, inp in ops:
    if name == 'Write':
        state[p] = inp.get('content', '')
    else:
        cur = state.get(p)
        if cur is None:
            missed.append(p)
            continue
        old, new = inp.get('old_string', ''), inp.get('new_string', '')
        if inp.get('replace_all'):
            state[p] = cur.replace(old, new)
        elif old in cur:
            state[p] = cur.replace(old, new, 1)
        else:
            missed.append(p)

restored = 0
for p, text in state.items():
    if os.path.exists(p):
        continue
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8') as fh:
        fh.write(text)
    if p.endswith('.sh'):
        os.chmod(p, 0o755)
    restored += 1
print(f'{len(ops)} write/edit ops from {len(files)} transcripts; restored {restored} files; '
      f'{len(set(missed))} files with an edit that could not be replayed')
for m in sorted(set(missed))[:20]:
    print('  edit not replayed:', m)

# the plan and its wrappers into the repo, where a reboot cannot reach them
PLAN = SCR + 'thuyvan_plan/'
for p in sorted(state):
    if not p.startswith(PLAN):
        continue
    rel = p[len(PLAN):]
    if rel.startswith('bin/'):
        dst = LANE + 'tools/thuyvan/bin/' + rel[4:]
    elif rel.endswith(('.md', '.json', '.py', '.txt')):
        dst = LANE + 'docs/thuyvan/plan/' + rel
    else:
        continue
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(p, dst)
print('copied into', LANE + 'docs/thuyvan/plan/ and tools/thuyvan/bin/')
for p in sorted(state):
    if p.startswith(PLAN):
        print('  ', p[len(PLAN):])
