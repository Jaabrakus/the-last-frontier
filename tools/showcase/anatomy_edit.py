#!/usr/bin/env python3
"""The damage-system trailer, cut (user 2026-09-30: "a trailer of this game now system and easy not to flashy human like").
Takes (tools/showcase/trailer.gd only=valley,hunt_map,man_down) on the big trailer's bar grid, with the quiet score
(anatomy_score.py) and the game's own sound low under it. Few cuts, long takes, dissolves, no hits.

    python3 tools/showcase/anatomy_edit.py <takes dir> <out.mp4> <work dir> [--sheet]
Uses trailer_edit's machinery with its own EDIT and TITLES."""
from __future__ import annotations

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trailer_edit as te  # noqa: E402
from trailer_edit import B, Clip, Title  # noqa: E402

te.EDIT = [
	# a quiet valley, the place and year over it
	Clip("valley", B(0), 7, src=0.8, fade_in=30, gain=-10.0),
	# the hunt: the stalk, the one shot, the deer going down where it stood
	Clip("hunt_map", B(1, 3), 14, sync=("loose", B(4, 0)), xfade=30, gain=-7.0),
	# the map under it, the camera drifting round: what the shot went through
	Clip("hunt_map", B(5, 1), 13, sync=("map", B(5, 3)), xfade=36, gain=-12.0),
	# a man shot in a meadow: he walks on, as a man does, and goes down
	Clip("man_down", B(8, 2), 22, sync=("shot", B(10, 0)), xfade=36, gain=-8.0),
	# the map over him
	Clip("man_down", B(14), 13, sync=("map", B(14, 2)), xfade=36, gain=-12.0, fade_out=30),
]
te.TITLES = [
	Title(B(0, 3), 8, [("THE UPPER MOHAWK VALLEY", "place"), ("1765", "year")], where="low", fade=16),
	Title(B(17), 10, [("FRONTIER", "title"), ("IN DEVELOPMENT", "place")], fade=24),
]
te.END = B(19, 2)


def main() -> None:
	args = sys.argv[1:]
	if len(args) < 3:
		raise SystemExit(__doc__)
	takes, out, work = args[0], args[1], args[2]
	os.makedirs(work, exist_ok=True)
	score = os.path.join(work, "score.wav")
	if "--sheet" not in args:
		subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "anatomy_score.py"), score,
				str(te.END / te.FPS)], check=True)
	sys.argv = ["trailer_edit.py", takes, out, work] + (["--sheet"] if "--sheet" in args else ["--music", score])
	te.main()


if __name__ == "__main__":
	main()
