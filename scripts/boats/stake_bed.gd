class_name StakeBed
extends RefCounted
## The building-bed puzzle of a canoe (BoatBuild stage "bed", puzzle "bed_stakes"; user 2026-09-29: "building it is a puzzle"), logic
## only. Seen from above, the stakes are driven into the gravel round the outline the bark will be shaped on, wide of the hull by a
## hand's breadth all along: the puzzle is to put each where it belongs. Positions are in metres on the ground, x across (right +),
## z along (bow +), the middle of the hull the origin. A stake is scored by how close it is to the nearest place still to be filled
## (TOLERANCE_M and it is worth nothing); the bed's score is the mean over all the stakes it wants (a missing stake counts nothing).
## A builder who knows the technique is shown the places; one who does not has the hull's length and beam and a centre line.
##   place(pos)   drives a stake at pos: its quality 0..1, or -1 when the bed is full
##   score()      0..1

const PAIRS := 7
const TOLERANCE_M := 0.4
const WIDE_M := 0.14

var targets: Array[Vector2] = []
var placed: Array[Vector2] = []
var quality: Array[float] = []
var length := 5.2
var beam := 0.95
var guided := true
var _taken: Array[bool] = []


static func make(hull: Dictionary, p_guided := true) -> StakeBed:
	var b := StakeBed.new()
	b.guided = p_guided
	b.length = float(hull.get("length", 5.2))
	b.beam = float(hull.get("beam", 0.95))
	for k in PAIRS:
		var t := -0.82 + 1.64 * float(k) / float(PAIRS - 1)
		var w := HullMesh.half_beam(hull, t) + WIDE_M
		for side: float in [1.0, -1.0]:
			b.targets.append(Vector2(side * w, t * b.length * 0.5))
			b._taken.append(false)
	return b


func wanted() -> int:
	return targets.size()


func full() -> bool:
	return placed.size() >= targets.size()


## Drives a stake at `pos`: the nearest place not yet filled decides how good it is.
func place(pos: Vector2) -> float:
	if full():
		return -1.0
	var best := -1
	var bd := INF
	for i in targets.size():
		if _taken[i]:
			continue
		var d := pos.distance_to(targets[i])
		if d < bd:
			bd = d
			best = i
	_taken[best] = true
	var q := clampf(1.0 - bd / TOLERANCE_M, 0.0, 1.0)
	placed.append(pos)
	quality.append(q)
	return q


func score() -> float:
	var s := 0.0
	for q in quality:
		s += q
	return s / float(maxi(targets.size(), 1))
