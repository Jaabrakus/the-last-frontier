"""Rebuilds the scratchpad's text files from the Write/Edit calls recorded in this session's transcripts (main + every
subagent and workflow agent), replayed in time order. Binary files (renders) cannot come back this way."""
import json, glob, os, sys
P = '/Users/kiwimango/.claude/projects/-Users-kiwimango-Downloads-Frontier--claude-worktrees-spellcraft/'
SID = '84dd193e-59da-450f-a5ed-c6e1c2e9b538'
SCR = '/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/84dd193e-59da-450f-a5ed-c6e1c2e9b538/scratchpad/'
files = []
for P in ['/Users/kiwimango/.claude/projects/-Users-kiwimango-Downloads-Frontier--claude-worktrees-spellcraft/',
          '/Users/kiwimango/.claude/projects/-Users-kiwimango-Downloads-Frontier/']:   # (the session's project key moved after a restart)
    files += glob.glob(P + SID + '.jsonl') + glob.glob(P + SID + '/subagents/**/*.jsonl', recursive=True)
ops = []
for f in files:
    if f.endswith('journal.jsonl'):
        continue
    try:
        fh = open(f, errors='replace')
    except Exception:
        continue
    for line in fh:
        if '"tool_use"' not in line or SCR[:-1] not in line:
            continue
        try:
            j = json.loads(line)
        except Exception:
            continue
        msg = j.get('message') or {}
        c = msg.get('content')
        if not isinstance(c, list):
            continue
        for b in c:
            if b.get('type') != 'tool_use' or b.get('name') not in ('Write', 'Edit'):
                continue
            inp = b.get('input') or {}
            fp = inp.get('file_path', '')
            if not fp.startswith(SCR):
                continue
            ops.append((j.get('timestamp') or '', f, b['name'], inp))
ops.sort(key=lambda o: o[0])
state = {}
bad = 0
for ts, f, name, inp in ops:
    fp = inp['file_path']
    if name == 'Write':
        state[fp] = inp.get('content', '')
    else:
        cur = state.get(fp)
        if cur is None:
            bad += 1
            continue
        old, new = inp.get('old_string', ''), inp.get('new_string', '')
        if old not in cur:
            bad += 1
            continue
        state[fp] = cur.replace(old, new) if inp.get('replace_all') else cur.replace(old, new, 1)
only = sys.argv[1:]  # optional path prefixes (relative to the scratchpad) to restore
n = 0
for fp, content in state.items():
    rel = fp[len(SCR):]
    if only and not any(rel.startswith(o) for o in only):
        continue
    if os.path.exists(fp):
        continue
    os.makedirs(os.path.dirname(fp), exist_ok=True)
    open(fp, 'w').write(content)
    n += 1
print(f'ops {len(ops)}, files known {len(state)}, restored {n}, edits that did not apply {bad}')
tops = {}
for fp in state:
    k = fp[len(SCR):].split('/')[0]
    tops[k] = tops.get(k, 0) + 1
print(sorted(tops.items(), key=lambda x: -x[1])[:60])
