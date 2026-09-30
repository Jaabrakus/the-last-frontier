class_name PitchSpread
extends RefCounted
## The pitch-spreading puzzle of a canoe's seams (BoatBuild stage "seams", puzzle "pitch"; user 2026-09-29: "building it is a puzzle"),
## logic only. The seam runs along the canoe, CELLS long, 0..1. A brush of hot pitch is drawn along it: the slower it moves over a
## cell the more it lays down there, the faster the less (a thin place leaks, a blob cracks); each cell wants a thickness in the band
## [lo, hi]. The pitch is only so much: `supply` is spent as it is laid (LUMP a lump). Finish (or the time out) and the score is how well the seam was
## covered: a cell in the band counts whole, thinner counts in proportion, thicker loses a little.
##   brush(x, dt)   the brush is at x (0..1) on the seam this step (pressed): lays pitch by how slowly it moves
##   lift()         the brush is up (no pitch, no speed carried)
##   score()        0..1
## The band is shown to a builder who knows the technique (`guided`).

const CELLS := 40
## Thickness laid a second on the cell under the brush: a slow brush spends more seconds on each cell, so lays more there.
const RATE := 6.0
## A lump of pitch covers about this much of the seam (in cell thickness): the supply of `lumps` lumps.
const LUMP := 13.0

var lo := 0.4
var hi := 0.9
var supply := 3.0 * LUMP
var duration := 35.0
var guided := true
var thick: Array[float] = []
var time := 0.0
var used := 0.0
var _x := -1.0


static func make(lumps := 3.0, p_duration := 35.0, p_guided := true) -> PitchSpread:
	var s := PitchSpread.new()
	s.supply = lumps * LUMP
	s.duration = p_duration
	s.guided = p_guided
	for i in CELLS:
		s.thick.append(0.0)
	return s


func done() -> bool:
	return time >= duration or used >= supply


func lift() -> void:
	_x = -1.0


## The brush at x this step (dt seconds), pressed: lays pitch on the cell under it from the supply. Nothing depends on the speed
## itself: a slow brush is on each cell for longer, a fast one skips along and leaves it thin.
func brush(x: float, dt: float) -> void:
	if done() or dt <= 0.0:
		return
	x = clampf(x, 0.0, 1.0)
	_x = x
	var c := clampi(int(x * float(CELLS)), 0, CELLS - 1)
	var give := minf(RATE * dt, supply - used)
	thick[c] += give
	# a little runs into the neighbours
	if c > 0:
		thick[c - 1] += give * 0.15
	if c < CELLS - 1:
		thick[c + 1] += give * 0.15
	used += give


func step(dt: float) -> void:
	if not done():
		time = minf(time + dt, duration)


func cell_score(t: float) -> float:
	if t < lo:
		return t / lo
	if t > hi:
		return maxf(1.0 - (t - hi) * 2.0, 0.0)
	return 1.0


func score() -> float:
	var s := 0.0
	for i in CELLS:
		s += cell_score(thick[i])
	return s / float(CELLS)
