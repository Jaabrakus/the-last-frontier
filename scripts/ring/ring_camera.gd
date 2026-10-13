class_name RingCamera
extends RefCounted
## The % ring's camera variants (round 4, READ; data/ring/camera.json): where the camera sits behind you, on top of MOVE's
## framing (movement.json cam: RingMoves.cam_bias). Why: under round 3's centred camera (arm 5.25 m, eye 2.6 m) a chest-high
## shot coming straight at you was hidden behind your own head and back for its last metre or two, just when a guard's
## timing is decided (the owner's FEEL list: "readable incoming attacks WITHOUT any target cue"). The variants:
##   close          A: round 3's view, unchanged
##   shoulder       B: over the right shoulder 0.5 m
##   high           C: centred and higher (the pivot +0.8 m, the arm +0.75 m), tilted down a little so the deck behind
##                  your feet shows: the default (the owner's "I don't want it off centre", said of the open world's guns,
##                  holds); a shot stays in view until about a metre out (tests/ring/test_ring_camera.gd: hidden_m)
##   high_shoulder  D: C a little over the right shoulder (0.25 m)
## A variant only ever moves the camera's arm, its pivot's lift, its shoulder and a fixed tilt of the camera about its own
## right axis. It never turns with a hit, never follows or turns toward the opponent (no lock-on), never touches the aim
## help; the crosshair stays the screen's centre (FrontierPlayer.get_aim_point). The open world never reads this (only a
## % ring's RingMoves calls apply()).
##   apply(out)              cam_bias's dictionary with the variant's arm, pivot_up, shoulder and tilt_deg added
##   key() / set_key(k)      the player's choice (GameSettings section ring, key camera; the Esc menu's Camera row), kept
##   override                a tool's or test's variant ("" the player's own)
##   jolt_on() / set_jolt()  the Esc menu's "Screen jolt" row: IMPACT's GameSettings ring.jolt (default on), written here
##   body_capsules(skel) / hidden(from, to, caps)   the hidden-shot metric: capsules fitted to the skeleton's bones and
##                           whether the line from the camera to a shot's centre passes through them

const PATH := "res://data/ring/camera.json"
const SECTION := "ring"
const KEY := "camera"
const JOLT_KEY := "jolt"

## A tool's or a test's variant ("" the player's own choice).
static var override := ""
static var _data := {}
static var _key := ""
static var _jolt := -1


static func data() -> Dictionary:
	if _data.is_empty():
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = v if v is Dictionary else {"default": "close", "variants": {"close": {}}}
	return _data


## The settings read again (a test's own settings file; the main menu's Settings changed).
static func reload() -> void:
	_key = ""
	_jolt = -1


static func default_key() -> String:
	return String(data().get("default", "close"))


## The variants in the Esc row's order.
static func keys() -> Array:
	var out := []
	var vs: Dictionary = data().get("variants", {})
	for k: Variant in data().get("menu_order", vs.keys()):
		if vs.has(String(k)):
			out.append(String(k))
	return out


## The variant in use: a tool's override, else the player's choice (read once), else the default.
static func key() -> String:
	var vs: Dictionary = data().get("variants", {})
	if override != "" and vs.has(override):
		return override
	if _key == "":
		var k := String(_read(KEY, default_key()))
		_key = k if vs.has(k) else default_key()
	return _key


static func variant(k := "") -> Dictionary:
	var vs: Dictionary = data().get("variants", {})
	return vs.get(k if k != "" else key(), {})


## The player's choice set and kept (at once: the next frame's cam_bias reads it). False for an unknown variant.
static func set_key(k: String) -> bool:
	if not (data().get("variants", {}) as Dictionary).has(k):
		return false
	_key = k
	GameSettings.set_value(SECTION, KEY, k)
	return true


static func next_key() -> String:
	var ks := keys()
	if ks.is_empty():
		return default_key()
	return String(ks[(ks.find(key()) + 1) % ks.size()])


static func label(k := "") -> String:
	return String(variant(k).get("label", k if k != "" else key()))


static func word(w: String) -> String:
	return String((data().get("words", {}) as Dictionary).get(w, w))


static func row_text() -> String:
	return word("row") % label()


static func row_line() -> String:
	var l := String(variant().get("line", ""))
	return l if l != "" else word("row_line")


## The Screen jolt row's switch (IMPACT reads GameSettings ring.jolt; default on).
static func jolt_on() -> bool:
	if _jolt < 0:
		_jolt = 1 if bool(_read(JOLT_KEY, true)) else 0
	return _jolt == 1


static func set_jolt(on: bool) -> void:
	_jolt = 1 if on else 0
	GameSettings.set_value(SECTION, JOLT_KEY, on)


static func jolt_row_text() -> String:
	return word("jolt_row") % word("jolt_on" if jolt_on() else "jolt_off")


## A key of the ring's settings section, read straight from the file (GameSettings.get_value needs a DEFAULTS entry: this
## section's defaults are the callers').
static func _read(k: String, dflt: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(GameSettings.file()) != OK:
		return dflt
	return cf.get_value(SECTION, k, dflt)


## RingMoves.cam_bias's framing with the variant on top: the deck's arm + arm_add (off the deck and hanging MOVE's own
## framing eases over it as before), the pivot's lift + pivot_add, the shoulder (m to the right), the tilt (deg down) and
## fov_add (deg over the view's own field; MOVE's off-deck field still eases over it).
static func apply(out: Dictionary, k := "") -> Dictionary:
	var v := variant(k)
	out["arm"] = float(out.get("arm", 0.0)) + float(v.get("arm_add", 0.0)) * (1.0 - clampf(float(out.get("pivot_w", 0.0)), 0.0, 1.0))
	out["pivot_up"] = float(out.get("pivot_up", 0.0)) + float(v.get("pivot_add", 0.0))
	out["shoulder"] = float(v.get("shoulder_m", 0.0))
	out["tilt_deg"] = float(v.get("tilt_deg", 0.0))
	out["fov_add"] = float(v.get("fov_add", 0.0))
	out["variant"] = k if k != "" else key()
	return out


# ---------------------------------------------------------------- the hidden-shot metric
## Radii (m) of the capsules fitted to the skeleton's bones (the player's rig: pelvis, spinea-d, neck, heada/b, the
## clavicles, shoulders, elbows, wrists, palms; the upper legs, knees, ankles, heels and balls), by a word in the bone's
## name (the first that matches): a bone's capsule runs from its parent's head to its own (so "knee" is the thigh, "elbow"
## the upper arm, "wrist" the forearm, "ankle" the shin). Bones matching SKIP (fingers, the face, twist, helper and
## offset bones, cloth and props) add none.
const RADII := [["head", 0.1], ["neck", 0.06], ["spine", 0.14], ["pelvis", 0.14], ["chest", 0.1], ["scapula", 0.06],
		["trap", 0.06], ["clavicle", 0.06], ["shoulder", 0.06], ["deltoid", 0.06], ["elbow", 0.055], ["wrist", 0.045],
		["palm", 0.045], ["upper_leg", 0.09], ["knee", 0.085], ["ankle", 0.06], ["heel", 0.05], ["ball", 0.045]]
const SKIP := ["helper", "twist", "offset", "muscle", "shirt", "holster", "collider", "attach", "index", "middle", "ring",
		"pinky", "thumb", "metacarpal", "brow", "lid", "lip", "cheek", "jaw", "chin", "nose", "nostril", "eye", "tongue",
		"squint", "laugh", "sneer", "frown", "bridge", "breast", "wrinkle", "throat", "root", "base", "grp"]
## A head bone's capsule runs this far up its own axis (m) from its head.
const HEAD_UP := 0.12


## Capsules [a, b, r] (world) fitted to `skel`'s bones in its pose now.
static func body_capsules(skel: Skeleton3D) -> Array:
	var caps := []
	if skel == null:
		return caps
	var xf := skel.global_transform
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i).to_lower()
		if _skip(nm):
			continue
		var r := _radius(nm)
		if r <= 0.0:
			continue
		var b := xf * skel.get_bone_global_pose(i).origin
		var par := skel.get_bone_parent(i)
		var a := xf * skel.get_bone_global_pose(par).origin if par >= 0 else b
		if nm.contains("head"):
			var up := (b - a).normalized() if a.distance_to(b) > 0.01 else Vector3.UP
			caps.append([b, b + up * HEAD_UP, r])
			continue
		if a.distance_to(b) > 0.6:
			a = b                                  # (a bone parented far away: its own sphere only)
		caps.append([a, b, r])
	return caps


static func _skip(nm: String) -> bool:
	for w: String in SKIP:
		if nm.contains(w):
			return true
	return false


static func _radius(nm: String) -> float:
	for e: Array in RADII:
		if nm.contains(String(e[0])):
			return float(e[1])
	return 0.0


## The line from `from` (the camera) to `to` (a shot's centre) passes through one of `caps`.
static func hidden(from: Vector3, to: Vector3, caps: Array) -> bool:
	for c: Array in caps:
		if seg_dist(from, to, c[0], c[1]) < float(c[2]):
			return true
	return false


## The closest distance between segments p1-q1 and p2-q2.
static func seg_dist(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-9 and e <= 1e-9:
		return p1.distance_to(p2)
	if a <= 1e-9:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-9:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-9 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)
