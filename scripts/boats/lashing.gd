class_name Lashing
extends RefCounted
## The gunwale-lashing puzzle of a canoe (BoatBuild stage "gunwales", puzzle "lashing"; user 2026-09-29: "building it is a puzzle"), logic
## only: the gunwales are sewn to the bark with wattap, stitch after stitch, and a good lashing keeps a rhythm. A marker sweeps back and
## forth across a bar; a stitch is pulled as it passes the middle, and how near it was to the middle is how good the stitch is. There are
## STITCHES of them; the marker quickens with each. The score is the mean of the stitches (one not pulled counts nothing). A builder who
## knows the technique is shown the middle; one who does not has only the bar (and the count of the stitches).
##   step(dt)     the marker moves
##   pull()       a stitch is pulled now: its quality 0..1
##   score()      0..1

const STITCHES := 12
const SWEET := 0.16
const SPEED0 := 0.9
const SPEED_UP := 1.06

var guided := true
var pos := 0.0            ## 0..1 across the bar
var quality: Array[float] = []
var _dir := 1.0
var _speed := SPEED0


static func make(p_guided := true, start := 0.1) -> Lashing:
	var l := Lashing.new()
	l.guided = p_guided
	l.pos = clampf(start, 0.0, 1.0)
	return l


func done() -> bool:
	return quality.size() >= STITCHES


func step(dt: float) -> void:
	if done() or dt <= 0.0:
		return
	pos += _dir * _speed * dt
	if pos >= 1.0:
		pos = 2.0 - pos
		_dir = -1.0
	elif pos <= 0.0:
		pos = -pos
		_dir = 1.0


func pull() -> float:
	if done():
		return -1.0
	var q := clampf(1.0 - absf(pos - 0.5) / SWEET, 0.0, 1.0)
	quality.append(q)
	_speed *= SPEED_UP
	return q


func score() -> float:
	var s := 0.0
	for q in quality:
		s += q
	return s / float(STITCHES)
