class_name RibSteam
extends RefCounted
## The rib-steaming puzzle of a canoe (BoatBuild stage "ribs", puzzle "rib_steam"; user 2026-09-29: "building it is a puzzle"), logic
## only. A cedar rib is steamed until it bends and then set under the gunwales: steamed too little it cracks, too long it goes mushy and
## will not hold its curve. Hold to steam a rib (its heat rises), let go to take it out and set it: the heat must be in the rib's window
## [lo, hi] (it varies a little rib to rib, with the wood). There are RIBS of them; the score is the mean of the ribs (a cracked one
## counts for little). A builder who knows the technique is shown the window on the gauge; one who does not sees only the wood's colour go
## from pale to amber to dark.
##   hold(dt)     the rib in the steam
##   release()    the rib taken out and set: its quality 0..1
##   score()      0..1

const RIBS := 7
const HEAT_PER_S := 0.24
const WINDOW := 0.2

var guided := true
var heat := 0.0
var quality: Array[float] = []
var windows: Array[Vector2] = []
var _holding := false


static func make(p_guided := true, seed_value := 1) -> RibSteam:
	var r := RibSteam.new()
	r.guided = p_guided
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in RIBS:
		var lo := rng.randf_range(0.5, 0.62)
		r.windows.append(Vector2(lo, lo + WINDOW))
	return r


func done() -> bool:
	return quality.size() >= RIBS


func window() -> Vector2:
	return windows[mini(quality.size(), RIBS - 1)]


func hold(dt: float) -> void:
	if done() or dt <= 0.0:
		return
	_holding = true
	heat = minf(heat + HEAT_PER_S * dt, 1.0)


func release() -> float:
	if done() or heat <= 0.0:
		return -1.0
	var w := window()
	var q := 1.0
	if heat < w.x:
		q = clampf(1.0 - (w.x - heat) / w.x * 1.6, 0.0, 1.0)      # still stiff: it cracks
	elif heat > w.y:
		q = clampf(1.0 - (heat - w.y) / (1.0 - w.y) * 1.4, 0.0, 1.0)  # mushy
	quality.append(q)
	heat = 0.0
	_holding = false
	return q


func score() -> float:
	var s := 0.0
	for q in quality:
		s += q
	return s / float(RIBS)
