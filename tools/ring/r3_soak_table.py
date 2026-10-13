"""Round 3's % ring soak table (smash_r3 spec §12) from tests/ring/test_ring_soak.gd's logs (rules=stock):
    python3 tools/ring/r3_soak_table.py <out.md> <log> [<log> ...]
Reads every run's METRIC lines ("pair=a-b stock ..." and "pair=a-b side=N stock ..." and the classic "side=N el=..." cast
lines), writes the per-pairing table and each §12 target with its value and whether it is met, and prints the targets as
METRIC lines."""
import re
import statistics
import sys


def nums(line):
    out = {}
    for k, v in re.findall(r'(\w+)=([-\w.{}:,"/ ]+?)(?=\s+\w+=|$)', line):
        out[k] = v.strip()
    return out


def f(v, d=None):
    try:
        return float(v)
    except (TypeError, ValueError):
        return d


def med(a):
    a = [x for x in a if x is not None]
    return statistics.median(a) if a else None


def mean(a):
    a = [x for x in a if x is not None]
    return sum(a) / len(a) if a else None


def main():
    out, logs = sys.argv[1], sys.argv[2:]
    runs = []
    for path in logs:
        try:
            text = open(path).read()
        except OSError:
            continue
        run = {'log': path, 'sides': [{}, {}], 'passed': 'RING SOAK PASSED' in text,
               'errors': text.count('SCRIPT ERROR')}
        for line in text.splitlines():
            if not line.startswith('METRIC pair='):
                continue
            pair = line.split()[1].split('=')[1]
            run['pair'] = pair
            m = re.search(r'side=(\d) stock el=(\w+) ko_by_move=(\{.*?\}) top_finisher_share=([\d.]+) recover_success=(\S+)', line)
            if m:
                s = int(m.group(1))
                run['sides'][s].update({'el': m.group(2), 'ko_by_move': m.group(3), 'top': f(m.group(4)),
                                        'recover': f(m.group(5))})
                continue
            m = re.search(r'side=(\d) el=(\w+) casts=(\d+) catches=(\d+).*share=([\d.]+)', line)
            if m:
                s = int(m.group(1))
                run['sides'][s].update({'el': m.group(2), 'casts': int(m.group(3)), 'catches': int(m.group(4)),
                                        'top_move_share': f(m.group(5))})
                continue
            m = re.search(r'side=(\d) guards clean=(\d+) perfect=(\d+)', line)
            if m:
                s = int(m.group(1))
                run['sides'][s].update({'clean': int(m.group(2)), 'perfect': int(m.group(3))})
                continue
            if ' stock=n/a' in line:
                run['na'] = True
            if ' stock ' in line and 'side=' not in line:
                for k, v in re.findall(r'(\w+)=(\S+)', line):
                    run[k] = v
        runs.append(run)
    stock = [r for r in runs if 'game_s' in r]
    rows = []
    hdr = ('| pairing | log | game s | time-out | lives level | life s | last life s | fall % | self/life | water | far KO | '
           'longest | median string | edge falls | air casts | heal/dmg | heal/life | winner |')
    rows.append(hdr)
    rows.append('|' + '|'.join(['---'] * (hdr.count('|') - 1)) + '|')
    for r in stock:
        rows.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
            r.get('pair'), r['log'].split('/')[-1], r.get('game_s'), r.get('timeout'), r.get('timeouts_level'), r.get('life_s'),
            r.get('last_life_s'), r.get('median_fall_pct'), r.get('self_falls_per_life'), r.get('water_ko_share'),
            r.get('ko_far_share'), r.get('longest_true_string'), r.get('median_string'), r.get('edge_fall_share'),
            r.get('air_release_share'), r.get('heal_share_of_damage'), r.get('heal_pct_per_life'), r.get('winner_el')))
    T = []

    def target(name, value, ok, want):
        T.append((name, value, ok, want))
        print('METRIC %s=%s target %s %s' % (name, value if value is not None else 'n/a', want,
                                             'ok' if ok else ('n/a' if value is None else 'MISSED')))

    g = [f(r.get('game_s')) for r in stock]
    v = med(g)
    target('median_game_s', v, v is not None and 240 <= v <= 420, '240-420')
    v = mean([f(r.get('timeout')) for r in stock])
    target('timeout_share', v, v is not None and v <= 0.10, '<= 0.10')
    v = mean([f(r.get('timeouts_level')) for r in stock])
    target('timeouts_level', v, v is not None and v <= 0.05, '<= 0.05')
    v = med([f(r.get('last_life_s')) for r in stock])
    target('last_life_s', v, v is not None, 'printed')
    v = med([f(r.get('life_s')) for r in stock])
    target('life_s', v, v is not None and 50 <= v <= 90, '50-90')
    v = med([f(r.get('median_fall_pct')) for r in stock])
    target('median_fall_pct', v, v is not None and 80 <= v <= 160, '80-160')
    v = mean([f(r.get('self_falls_per_life')) for r in stock])
    target('self_falls_per_life', v, v is not None and v <= 0.05, '<= 0.05')
    v = min([f(r.get('water_ko_share'), 1.0) for r in stock]) if stock else None
    target('water_ko_share', v, v is not None and v >= 0.999, '1.0')
    v = mean([f(r.get('ko_far_share')) for r in stock])
    target('ko_far_share', v, v is not None and v <= 0.3, '<= 0.3')
    tops = [s.get('top_move_share') for r in runs for s in r['sides'] if s.get('top_move_share') is not None]
    v = max(tops) if tops else None
    target('top_move_share', v, v is not None and v <= 0.25, '<= 0.25 (the worst side)')
    v = max([int(f(r.get('longest_true_string'), 0)) for r in stock]) if stock else None
    target('longest_true_string', v, v is not None and v <= 6, '<= 6')
    v = med([f(r.get('median_string')) for r in stock])
    target('median_true_string', v, v is not None and 1.5 <= v <= 2.5, '2')
    by_el = {}
    for r in stock:
        for s in r['sides']:
            if s.get('recover') is not None:
                by_el.setdefault(s['el'], []).append(s['recover'])
    rec = {e: mean(a) for e, a in by_el.items()}
    spread = (max(rec.values()) - min(rec.values())) if rec else None
    target('recover_success_spread', spread, spread is not None and spread <= 0.15, 'within 0.15 (%s)' % {e: round(x, 2) for e, x in rec.items()})
    v = mean([f(r.get('edge_fall_share')) for r in stock])
    target('edge_fall_share', v, v is not None and 0.15 <= v <= 0.5, '0.15-0.5')
    v = mean([f(r.get('air_release_share')) for r in stock])
    target('air_release_share', v, v is not None and 0.15 <= v <= 0.35, '0.15-0.35')
    v = mean([f(r.get('heal_share_of_damage')) for r in stock])
    target('heal_share_of_damage', v, v is not None and v <= 0.15, '<= 0.15')
    v = mean([f(r.get('heal_pct_per_life')) for r in stock])
    target('heal_pct_per_life', v, v is not None, 'printed')
    wins, plays = {}, {}
    for r in stock:
        a, b = (r.get('pair') or '-').split('-')
        if a == b:
            continue
        for e in (a, b):
            plays[e] = plays.get(e, 0) + 1
        w = r.get('winner_el')
        if w in (a, b):
            wins[w] = wins.get(w, 0) + 1
    shares = {e: wins.get(e, 0) / plays[e] for e in plays}
    ok = bool(shares) and all(0.4 <= x <= 0.6 for x in shares.values())
    target('element_win_share', shares or None, ok, '0.40-0.60 each, non-mirror')
    fin = {}
    for r in stock:
        for s in r['sides']:
            if s.get('ko_by_move'):
                d = {}
                for k, n in re.findall(r'"([^"]+)": (\d+)', s['ko_by_move']):
                    d[k] = int(n)
                acc = fin.setdefault(s['el'], {})
                for k, n in d.items():
                    acc[k] = acc.get(k, 0) + n
    tops = {e: (max(d.values()) / sum(d.values()) if d and sum(d.values()) else None) for e, d in fin.items()}
    worst = max([x for x in tops.values() if x is not None], default=None)
    target('ko_by_move_top_finisher', worst, worst is not None and worst <= 0.5, '<= 0.5 of an element\'s falls dealt (%s)' % {e: round(x, 2) for e, x in tops.items() if x is not None})
    printed = {k: sum(int(f(r.get(k), 0)) for r in stock) for k in ('helpless_kos', 'breaks')}
    printed['catches'] = sum(s.get('catches', 0) for r in runs for s in r['sides'])
    printed['clean_catches'] = sum(s.get('clean', 0) for r in runs for s in r['sides'])
    printed['perfect_guards'] = sum(s.get('perfect', 0) for r in runs for s in r['sides'])
    gr = [r.get('grabs_refused') for r in stock if r.get('grabs_refused') not in (None, 'n/a')]
    printed['grabs_refused'] = sum(int(f(x, 0)) for x in gr) if gr else 'n/a'
    print('METRIC printed %s' % printed)
    lines = ['# Round 3 BOTS: the % ring soak (smash_r3 spec §12)', '',
             'tests/ring/test_ring_soak.gd rules=stock, normal bots, time scale 1; %d runs read, %d played the stock rules '
             '(%d passed, %d SCRIPT ERROR lines).' % (len(runs), len(stock), sum(1 for r in runs if r['passed']),
                                                      sum(r['errors'] for r in runs)), '']
    if not stock:
        lines += ['**No run played the stock rules** (the ring played its rules.json rule set: PERCENT\'s RingMode must take '
                  'MatchSetup.rule_set()). Every target below is n/a.', '']
    lines += ['## Targets', '', '| metric | value | target | met |', '|---|---|---|---|']
    for name, value, ok, want in T:
        lines.append('| %s | %s | %s | %s |' % (name, value if value is not None else 'n/a', want,
                                                'yes' if ok else ('n/a' if value is None else '**no**')))
    lines += ['', 'Printed: %s' % printed, '', '## Per run', ''] + rows
    open(out, 'w').write('\n'.join(lines) + '\n')
    print('wrote %s' % out)


if __name__ == '__main__':
    main()
