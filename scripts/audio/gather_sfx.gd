class_name GatherSfx
extends RefCounted
## Gathering sounds (push n12s): which sound each gathering event plays, with a little gain and pitch on top of
## the manifest's own random pitch and volume. The sounds (audio/sfx/gathering_rec/, tools/sfx/gathering_rec.py)
## are layered from real CC0 recordings; audio/sfx/gathering_rec/SOURCE.md lists the packs and the takes.
##
##   GatherSfx.mining_strike(point, power)      a mattock / pick stroke on rock (power: the Mining skill's stroke
##                                              power, 1 at level 0 to 1.8; stronger strokes bite deeper more often)
##   GatherSfx.stone_breaks(point, last)        a piece breaks off (last: the outcrop is used up)
##   GatherSfx.chop(point, diameter_m)          the felling axe into a standing trunk (big trunks: a deeper body)
##   GatherSfx.sapling(point)                   a stroke into a sapling
##   GatherSfx.buck(point, diameter_m)          bucking a fallen log
##   GatherSfx.tree_falls(stump, dir, length_m, fall_s)
##                                              the hinge cracks and the trunk groans now; the crown's swish is
##                                              started so its peak meets the ground fall_s from now
##   GatherSfx.tree_lands(point, length_m)      the trunk hits the ground
##
## Each returns the sound id it played. `played` keeps the latest ids and `counts` how often each id played (tests
## read them; reset_log() clears both); nothing is heard headless.
## The ids all start with gather_rec_ (the gathering push's own synthesized sounds, audio/sfx/gathering/, keep
## their names as a fallback).

const BIG_TRUNK_M := 0.65      ## trunks this thick and more chop with gather_rec_axe_chop_big
## gather_rec_tree_fall's swish peaks this long after it starts (tools/sfx/gathering_rec.py PEAK_S); tree_falls
## starts it so the peak meets the landing, and 0.5 s of tail after the peak covers a landing a little off.
const FALL_PEAK_S := 1.6
const MAX_LOG := 64
const G := 9.8                 ## as FelledTree

## Every id each event can play (tests, docs).
const EVENTS := {
	"mining_strike": [&"gather_rec_pick_rock", &"gather_rec_pick_rock_hard"],
	"stone_breaks": [&"gather_rec_rock_split", &"gather_rec_rock_depleted"],
	"chop": [&"gather_rec_axe_chop", &"gather_rec_axe_chop_big"],
	"sapling": [&"gather_rec_axe_chop_sapling"],
	"buck": [&"gather_rec_buck"],
	"tree_falls": [&"gather_rec_tree_crack", &"gather_rec_tree_fall"],
	"tree_lands": [&"gather_rec_tree_land"],
}

static var rng := RandomNumberGenerator.new()
static var played: Array[StringName] = []
static var counts := {}        ## id -> times played since reset_log()
## Tests: play through Sfx even headless (voices start with the Dummy audio driver; nothing is heard).
static var audible_headless := false


static func mining_strike(point: Vector3, power := 1.0) -> StringName:
	var t := clampf((power - 1.0) / 0.8, 0.0, 1.0)
	var hard := rng.randf() < clampf(0.15 + 0.7 * t, 0.1, 0.9)
	var id := &"gather_rec_pick_rock_hard" if hard else &"gather_rec_pick_rock"
	return _play(id, point, -1.0 + 1.5 * t + rng.randf_range(-0.75, 0.75), rng.randf_range(0.97, 1.03))


static func stone_breaks(point: Vector3, last := false) -> StringName:
	# just after the strike that broke it
	var id := &"gather_rec_rock_depleted" if last else &"gather_rec_rock_split"
	return _play(id, point, rng.randf_range(-1.0, 1.0), rng.randf_range(0.96, 1.04), 0.06 if last else 0.04)


static func chop(point: Vector3, diameter_m := 0.5) -> StringName:
	var id := &"gather_rec_axe_chop_big" if diameter_m >= BIG_TRUNK_M else &"gather_rec_axe_chop"
	var pitch := clampf(1.0 + (0.55 - diameter_m) * 0.25, 0.92, 1.08) * rng.randf_range(0.98, 1.02)
	return _play(id, point, rng.randf_range(-1.0, 1.0), pitch)


static func sapling(point: Vector3) -> StringName:
	return _play(&"gather_rec_axe_chop_sapling", point, rng.randf_range(-1.0, 1.0), rng.randf_range(0.95, 1.08))


static func buck(point: Vector3, diameter_m := 0.5) -> StringName:
	var pitch := clampf(1.0 + (0.5 - diameter_m) * 0.3, 0.92, 1.08) * rng.randf_range(0.98, 1.02)
	return _play(&"gather_rec_buck", point, rng.randf_range(-1.0, 1.0), pitch)


## The tree starts to go: the hinge cracks and the trunk groans at the stump now; the crown's swish through the
## air is started so its peak lands with the trunk (fall_s: seconds from now to the landing, e.g.
## fall_time(length, felling); < 0 uses fall_time(length_m) with the default felling numbers). Returns the swish's
## id.
static func tree_falls(stump: Vector3, dir: Vector3, length_m: float, fall_s := -1.0) -> StringName:
	var pitch := clampf(1.0 + (18.0 - length_m) * 0.01, 0.9, 1.08)
	_play(&"gather_rec_tree_crack", stump + Vector3.UP, 0.0, pitch * rng.randf_range(0.98, 1.02))
	var t := fall_s if fall_s >= 0.0 else fall_time(length_m)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 1e-4 else Vector3.FORWARD
	var mid := stump + (Vector3.UP + flat) * (0.45 * length_m)
	return _play(&"gather_rec_tree_fall", mid, 0.0, rng.randf_range(0.99, 1.01), maxf(t - FALL_PEAK_S, 0.0))


static func tree_lands(point: Vector3, length_m := 18.0) -> StringName:
	var pitch := clampf(1.0 + (18.0 - length_m) * 0.012, 0.88, 1.1) * rng.randf_range(0.98, 1.02)
	return _play(&"gather_rec_tree_land", point, clampf((length_m - 18.0) * 0.2, -3.0, 3.0), pitch)


## Seconds a felled tree of this length (hinge to top) takes from upright to the ground on flat ground: the same
## pole-and-crown fall as FelledTree, integrated the same way at 120 Hz, with the gathering data's felling numbers
## (crown_mass, fall_start_deg, fall_push; FelledTree's defaults when missing).
static func fall_time(length_m: float, felling := {}, contact_deg := 88.0) -> float:
	var mc := clampf(float(felling.get("crown_mass", 0.35)), 0.0, 0.9)
	var k := ((1.0 - mc) * 0.5 + mc * 0.7) / ((1.0 - mc) / 3.0 + mc * 0.49)
	var th := deg_to_rad(float(felling.get("fall_start_deg", 1.5)))
	var om := float(felling.get("fall_push", 0.12))
	var t := 0.0
	var dt := 1.0 / 120.0
	var stop := deg_to_rad(contact_deg)
	var l := maxf(length_m, 2.0)
	while th < stop and t < 20.0:
		om += k * G / l * sin(th) * dt
		th += om * dt
		t += dt
	return t


static func reset_log() -> void:
	played.clear()
	counts.clear()


## Plays `id` at `pos` (delay >= 0: that much later than the event, plus the sound's travel time to the
## listener, which Sfx adds by itself only when no delay is given).
static func _play(id: StringName, pos: Vector3, gain_db: float, pitch: float, delay := -1.0) -> StringName:
	played.append(id)
	if played.size() > MAX_LOG:
		played.remove_at(0)
	counts[id] = int(counts.get(id, 0)) + 1
	if (DisplayServer.get_name() == "headless" and not audible_headless) or not Sfx.has(id):
		return id
	var opts := {}
	if delay >= 0.0:
		opts["delay"] = maxf(delay + Sfx.travel_delay(pos), 0.001)
	Sfx.play_3d(id, pos, gain_db, pitch, opts)
	return id
