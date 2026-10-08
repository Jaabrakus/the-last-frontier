"""Report test_balance.gd logs with explicit, different win-rate denominators.

    python3 tools/ring/balance_report.py run.log --markdown report.md --json report.json
    python3 tools/ring/balance_report.py run.log holdout.log --require-balanced

Combine only runs of the same gameplay configuration. Mirrors do not affect elemental
balance. A 25% share of all decided wins corresponds to a 50% personal 1v1 win rate
only with equal participation and no draws. The 40–60% screen is a sampling tolerance,
not a claim that human players or every matchup are balanced.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import statistics

ELEMENTS = ("earth", "water", "fire", "air")
GAME = re.compile(
    r"^BAL GAME (\w+)-(\w+) winner=(\w+) seat=(-?\d+) game_s=([\d.]+) "
    r"lost=(\d+):(\d+) strings=(\d+)/(\d+)/(\d+) kos0=(\{.*?\}) kos1=(\{.*\})$"
)


def parse_log(text: str, name: str = "input") -> dict:
    games = []
    for line in text.splitlines():
        if not line.startswith("BAL GAME "):
            continue
        match = GAME.fullmatch(line)
        if match is None:
            raise ValueError(f"{name}: malformed game record")
        a, b, winner, seat, seconds, lost0, lost1, s1, s2, s3, ko0, ko1 = match.groups()
        seat = int(seat)
        if a not in ELEMENTS or b not in ELEMENTS or seat not in (-1, 0, 1):
            raise ValueError(f"{name}: unknown element or winner seat")
        if winner != ([a, b][seat] if seat >= 0 else "none"):
            raise ValueError(f"{name}: winner name and seat disagree")
        kos = [json.loads(ko0), json.loads(ko1)]
        if any(not isinstance(k, dict) or any(type(v) is not int or v < 0 for v in k.values()) for k in kos):
            raise ValueError(f"{name}: invalid KO counts")
        games.append({"elements": [a, b], "winner": winner, "seat": seat,
                      "seconds": float(seconds), "lost": [int(lost0), int(lost1)],
                      "strings": [int(s1), int(s2), int(s3)], "kos": kos})
    terminal = re.findall(r"^BALANCE (PASSED|FAILED)\b.*$", text, re.MULTILINE)
    return {"name": name, "games": games, "complete": bool(terminal),
            "smoke_passed": bool(terminal) and terminal[-1] == "PASSED",
            "script_errors": text.count("SCRIPT ERROR")}


def summarize(runs: list[dict]) -> dict:
    games = [g for run in runs for g in run["games"]]
    cross = [g for g in games if g["elements"][0] != g["elements"][1]]
    totals = {el: {"wins": 0, "games": 0, "lives_won": 0, "lives_decided": 0} for el in ELEMENTS}
    pairs = Counter()
    matchups = {a: {b: {"wins": 0, "games": 0} for b in ELEMENTS if b != a} for a in ELEMENTS}
    strings = [0, 0, 0]
    decided = 0
    for game in cross:
        a, b = game["elements"]
        pairs[f"{a}-{b}"] += 1
        life_counts = [sum(k.values()) for k in game["kos"]]
        for seat, element in enumerate((a, b)):
            t = totals[element]
            t["games"] += 1
            t["wins"] += game["seat"] == seat
            t["lives_won"] += life_counts[seat]
            t["lives_decided"] += sum(life_counts)
            versus = matchups[element][(a, b)[1 - seat]]
            versus["games"] += 1
            versus["wins"] += game["seat"] == seat
        decided += game["seat"] >= 0
        strings = [x + y for x, y in zip(strings, game["strings"])]
    expected_pairs = [f"{a}-{b}" for a in ELEMENTS for b in ELEMENTS if a != b]
    schedule = [pairs[p] for p in expected_pairs]
    equal_schedule = min(schedule) > 0 and len(set(schedule)) == 1
    reasons = []
    if not runs or any(not r["complete"] or not r["smoke_passed"] for r in runs):
        reasons.append("A run is incomplete or failed its runtime smoke checks.")
    if any(r["script_errors"] for r in runs):
        reasons.append("The logs contain script errors.")
    if not equal_schedule or min(schedule) < 3:
        reasons.append("Need at least three games for every ordered cross-element pairing, with equal counts.")
    if decided != len(cross):
        reasons.append("Some non-mirror games have no winner.")
    for element, t in totals.items():
        t["win_rate"] = t["wins"] / t["games"] if t["games"] else None
        t["pooled_win_share"] = t["wins"] / decided if decided else None
        t["life_share"] = t["lives_won"] / t["lives_decided"] if t["lives_decided"] else None
        if t["win_rate"] is None or not 0.4 <= t["win_rate"] <= 0.6:
            reasons.append(f"{element.title()} is outside the 40–60% personal win-rate screen.")
    return {"logs": [r["name"] for r in runs], "games": len(games), "cross_games": len(cross),
            "mirror_games": len(games) - len(cross), "decided_cross_games": decided,
            "equal_schedule": equal_schedule, "games_per_ordered_pair": min(schedule) if equal_schedule else None,
            "pairs": {p: pairs[p] for p in expected_pairs}, "elements": totals, "matchups": matchups,
            "median_game_seconds": statistics.median(g["seconds"] for g in cross) if cross else None,
            "strings_1_2_3plus": strings, "screen_passed": not reasons, "reasons": reasons}


def markdown(report: dict) -> str:
    def pct(value):
        return "n/a" if value is None else f"{value:.1%}"

    lines = ["# Element balance", "",
             f"{report['cross_games']} non-mirror games; {report['mirror_games']} mirrors excluded.", "",
             "| Element | Wins / own games | Personal 1v1 win rate (aim 50%) | Share of all wins (aim 25%) | Credited stock share |",
             "| --- | --- | --- | --- | --- |"]
    for el, t in report["elements"].items():
        lines.append(f"| {el.title()} | {t['wins']} / {t['games']} | {pct(t['win_rate'])} | "
                     f"{pct(t['pooled_win_share'])} | {pct(t['life_share'])} |")
    lines += ["", "Wins against each opponent (both seats combined):", "",
              "| Element | Earth | Water | Fire | Air |", "| --- | --- | --- | --- | --- |"]
    for element in ELEMENTS:
        cells = []
        for opponent in ELEMENTS:
            if element == opponent:
                cells.append("—")
            else:
                pair = report["matchups"][element][opponent]
                cells.append(f"{pair['wins']} / {pair['games']}")
        lines.append("| " + " | ".join([element.title(), *cells]) + " |")
    lines += ["", "Finite-sample screen: " + ("PASS" if report["screen_passed"] else "NOT MET"), ""]
    lines.extend(f"- {reason}" for reason in report["reasons"])
    lines += ["", "A pass requires a complete equal schedule (at least three games in both seats for every matchup), "
              "no script errors or failed smoke checks, no draws, and 40–60% personal win rates. "
              "This is a screening band around the goal, not proof of exact equality or a human skill curve.", "",
              "The 25% pooled target assumes equal participation. Do not combine logs from different gameplay configurations.", "",
              "Inputs:", ""]
    lines.extend(f"- `{path}`" for path in report["logs"])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs="+", type=Path)
    parser.add_argument("--markdown", type=Path)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--require-balanced", action="store_true")
    args = parser.parse_args()
    if len({p.resolve() for p in args.logs}) != len(args.logs):
        parser.error("duplicate log paths would count the same games twice")
    try:
        report = summarize([parse_log(p.read_text(), str(p)) for p in args.logs])
    except (OSError, ValueError) as error:
        parser.error(str(error))
    result = markdown(report)
    print(result, end="")
    if args.markdown:
        args.markdown.write_text(result)
    if args.json:
        args.json.write_text(json.dumps(report, indent=2) + "\n")
    return int(args.require_balanced and not report["screen_passed"])


if __name__ == "__main__":
    raise SystemExit(main())
