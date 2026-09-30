class_name BarkFit
extends RefCounted
## The bark-fitting puzzle of a bark canoe's skin (BoatBuild stage "skin", puzzle "bark_fit"; user 2026-09-29: "building it is a
## puzzle"), logic only. The bark is laid over the bed and stretched to the frame: pressed down along its length, it must be drawn
## evenly, taut, not slack and not overstretched. It is ZONES sections stern to bow, each with a tension 0..1 that slowly relaxes
## (bark springs back); pressing a section draws it tighter and its neighbours a little; the target is the band [lo, hi] all along.
## Over-drawn too long a section tears (a sheet is spoilt: a penalty, the section relaxed). Time runs for `duration` seconds and the
## score is how much of it the skin spent evenly in the band, less the tears.
##   press(i)     one press on a section
##   step(dt)     time passes (sampled for the score every SAMPLE_S)
##   score()      0..1
## The band is per skin (its thickness: `lo`, `hi`); a builder who knows the technique is shown it (`guided`); one who does not judges
## by the colour of the bark alone (the screen).

const ZONES := 7
const SAMPLE_S := 0.25
const PRESS := 0.20
const SIDE := 0.07
const RELAX_PER_S := 0.045
const TEAR_AT := 0.94
const TEAR_HOLD_S := 0.5
const TEAR_PENALTY := 0.12
const START := 0.15

var lo := 0.45
var hi := 0.72
var duration := 28.0
var guided := true
var tension: Array[float] = []
var tears := 0
var time := 0.0
var _hot: Array[float] = []
var _samples := 0
var _good := 0.0
var _next_sample := 0.0


static func make(p_lo := 0.45, p_hi := 0.72, p_duration := 28.0, p_guided := true, seed_value := 1) -> BarkFit:
	var b := BarkFit.new()
	b.lo = p_lo
	b.hi = p_hi
	b.duration = p_duration
	b.guided = p_guided
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in ZONES:
		b.tension.append(clampf(START + rng.randf_range(-0.05, 0.08), 0.0, 1.0))
		b._hot.append(0.0)
	return b


func done() -> bool:
	return time >= duration


func in_band(i: int) -> bool:
	return tension[i] >= lo and tension[i] <= hi


func press(i: int) -> void:
	if i < 0 or i >= ZONES or done():
		return
	tension[i] = minf(tension[i] + PRESS, 1.0)
	if i > 0:
		tension[i - 1] = minf(tension[i - 1] + SIDE, 1.0)
	if i < ZONES - 1:
		tension[i + 1] = minf(tension[i + 1] + SIDE, 1.0)


func step(dt: float) -> void:
	if done() or dt <= 0.0:
		return
	time = minf(time + dt, duration)
	for i in ZONES:
		tension[i] = maxf(tension[i] - RELAX_PER_S * dt, 0.0)
		if tension[i] >= TEAR_AT:
			_hot[i] += dt
			if _hot[i] >= TEAR_HOLD_S:
				tears += 1
				tension[i] = 0.3
				_hot[i] = 0.0
		else:
			_hot[i] = 0.0
	while time >= _next_sample and _samples < int(duration / SAMPLE_S) + 1:
		var n := 0
		for i in ZONES:
			if in_band(i):
				n += 1
		_good += float(n) / float(ZONES)
		_samples += 1
		_next_sample += SAMPLE_S


## 0..1: the share of the time the skin was evenly in its band, less TEAR_PENALTY a tear.
func score() -> float:
	if _samples == 0:
		return 0.0
	return clampf(_good / float(_samples) - TEAR_PENALTY * float(tears), 0.0, 1.0)


## The section that most needs pressing (a helper for the tests' bot and for hints): the furthest under the band.
func slackest() -> int:
	var best := 0
	for i in ZONES:
		if tension[i] < tension[best]:
			best = i
	return best
