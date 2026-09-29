extends SceneTree
## Loadout handoff survey: where the hands go in every draw / stow / holster / switch clip of
## Actor_B, measured on the real rig, and the stowed transform that makes a sling / holster handoff
## seamless. Writes data/loadout/handoffs.json (summary) and data/loadout/handoffs_cases.json (every
## case in full); explained in source/graph_analysis/loadout/handoff_survey.md.
##
##   python3 tools/loadout/resolve_loadout_graph.py        (first: graph selections it summarises)
##   Godot --headless --path . -s tools/loadout/measure_handoffs.gd -- [out=<path>] [only=<substring>]
##
## Always run Godot under a hard time limit (a script error can leave it running). About 5 s.
## Exit code 0 and "HANDOFFS OK" on success, 1 and "HANDOFFS FAILED" otherwise.
##
## Composition (the runtime's, UpperBody + PropFlipGuard at full action weight):
##   base   = the idle role of the weapon profile and stance (roles.<w>/<run|crouch>/idle: clip at t = 0
##            plus its layers at their graph weights), evaluated once in a scratch AnimationTree
##            (deterministic, callback MANUAL) on characters/Actor_B.tscn after BindRest.ensure();
##   action = the partial replaces every bone it keys (prop bones included: PropFlipGuard plays the
##            partial on them; at weight 1 that is the clip's own pose), then the additive twin is
##            added (Godot Add2: rot = base * rest^-1 * add, pos += add - rest, scale += add - rest),
##            twin phase = partial phase;
##   the pose is sampled at 60 Hz and the skeleton-space transforms come from forward kinematics.
##   Every unmirrored case is re-evaluated in a full AnimationTree (base + layers + Blend2(partial,
##   filtered) + Add2(twin) behind TimeSeek nodes) at phases 0, 0.5, 1; meta.validation holds the
##   worst prop-bone difference (the run fails above 2 mm).
##   Mirrored cases (id prefix "M:") play a right-hand clip on the left side (or the reverse): every
##   keyed local transform is reflected through the sagittal plane, L'(b) = F(parent)^-1 L(partner(b))
##   F(b) with F(b) = G_rest(partner(b))^-1 diag(-1,1,1) G_rest(b) (exact for this l_/r_-symmetric
##   rig), over the unmirrored base: what a mirrored copy of the clip would do at runtime.
##
## Hand point: the palm carrying the prop bone's REST offset (where a held grip sits). The prop bone
## itself is keyed by the clips (two-hand weapons key both prop bones on the weapon; parked objects
## are keyed on the body until the hand takes them), so it gives the stowed transform, the hand point
## gives the reach.
##
## Grab / release frame, per hand, in this order:
##   1 a body prop transfer: the prop bone goes from parked on the body (resting between the clip's
##     last two keys on that side, <= PARK_DRIFT in the body frame) into the hand (<= PROP_ON of the
##     hand point), or back (>= PROP_OFF); X^idle clips: first half, idle^X: second half. The frame is
##     snapped to the in-hand key next to the parked key; the parked key gives the source's own
##     stowed pose ("parked"). Passes between the hands ("other_hand") and objects moving between
##     keys ("in_flight") are listed but never used;
##   2 the junction by the source naming (A^B = from A to B): X^idle -> first frame, idle^X -> last
##     frame (the seam between the graph's grab and draw states; the draw leaf is p-grab^idle-GUNOUT:
##     the gun is in the hand from its first frame; a reversed draw, the holster, ends on it);
##   3 gestures that start and end in the carry pose (switch hands, pack stash): the frame farthest
##     from the carry pose among the slow frames (speed <= max(0.3 x peak, 0.25 m/s)).
## hands.*.arrival is the slowest frame on the grab side (first / last 40 %), a speed-minimum
## cross-check. At the grab frame the prop bones are expressed in holster_long / holster_pistol /
## holster_melee / pelvis / spinec / spined space ("prop_in") and so is the weapon model
## ("model_in" = prop * half turn about Y, Frontier's socket offset): a model reparented there with
## that transform stays exactly where the hand left it.
##
## Body frame ("bind_equiv"): a point carried back into the bind pose by the nearest torso anchor
## (pelvis, spinea, spineb, spinec, spined), for regions and belt coordinates (belt azimuth: 0 front,
## +90 left, -90 right, 180 back; height above the belt mid line; distance outside the belt ring).
##
## Carry points: belt ring and chest points measured on the body mesh (assets/character/
## actor_b_body.glb: Gear 'belt' band, Clothes 'coat' / 'waistcoat' surfaces; bind pose = rig rest),
## grip point = surface + GRIP_OUT outward (+ GRIP_UP above the belt mid line), carried by the pelvis
## (belt) or spinec (chest). Per case and hand: distance at the grab frame, smallest over slow frames
## (a usable clip segment), smallest at any speed (a pass).
##
## Also: stow points (the source's stow places with parked and in-hand transforms and the
## stand-vs-crouch difference per carrying space), the graph's playback of every draw / holster
## action (rate callback, reverse, Frontier equip_time), grab -> draw and draw -> holster_finish
## continuity, stow-parent drift over locomotion, and the graph selections summary (unarmed profile,
## backpack-off draw / holster clips) from data/loadout/graph_selections.json.
##
## Nothing in the project is changed except the two output files. Axes: skeleton space, +Z =
## character forward, +X = character LEFT, +Y = up (the rig faces +Z; the player turns it 180 deg).
##
## Provenance: asset IDs (native_asset_id) are copied into the output.

const RIG := "res://characters/Actor_B.tscn"
const LIB := "actor_b"
const GRAPH := "res://animations/actor_b_graph.json"
const BODY := "res://assets/character/actor_b_body.glb"
const GRAPH_SEL := "res://data/loadout/graph_selections.json"
const DEFAULT_OUT := "res://data/loadout/handoffs.json"
const GENERATOR := "tools/loadout/measure_handoffs.gd"
const SCHEMA := 1

const HZ := 60.0
const HALF_TURN := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
const HOLSTERS := ["holster_long", "holster_pistol", "holster_melee"]
const SPACES := ["holster_long", "holster_pistol", "holster_melee", "pelvis", "spinec", "spined"]
const PROP := {"r": "r_hand_prop_attachment", "l": "l_hand_prop_attachment"}
const TRACKED := ["r_hand_prop_attachment", "l_hand_prop_attachment", "r_palm", "l_palm", "r_wrist", "l_wrist", "holster_long",
		"holster_pistol", "holster_melee", "root", "pelvis", "spineb", "spinec", "spined", "r_clavicle",
		"l_clavicle", "neck"]
const STANCE_MODE := {"stand": "run", "crouch": "crouch"}
## Torso anchors of the body-frame (bind-equivalent) positions, see _bind_equiv.
const ANCHORS := ["pelvis", "spinea", "spineb", "spinec", "spined"]
## Slow-frame rule of the grab / release frame (see header).
const SLOW_REL := 0.3
const SLOW_ABS := 0.25
## Prop transfer: the prop bone counts as in the hand within PROP_ON of the hand point and as parked
## (on the body / hidden) beyond PROP_OFF (hysteresis).
const PROP_ON := 0.06
const PROP_OFF := 0.10
## A prop counts as parked on the body when it moves less than PARK_DRIFT (body frame) between the
## clip's last two keys on the parked side of the transfer; else it is in flight (a pass).
const PARK_DRIFT := 0.03
## Hold window: frames within this of the grab position.
const HOLD_TOL := 0.03
## Carry points: grip offset from the garment surface (outward) and above the belt's mid line.
const GRIP_OUT := 0.03
const GRIP_UP := 0.05
const BELT_MID_Y := 0.942
const BELT_STEP_DEG := 15.0
const CHEST_Y := [1.05, 1.15, 1.25]
const CHEST_AZ := [-45.0, -30.0, 0.0, 30.0, 45.0]
## Outfit bulk sensitivity (outermost layer envelope, customizer: coat 15 mm, wraps >= 22, fur env50).
const BULK := [0.0, 0.025, 0.05]
## Reach verdicts (hand-to-point error).
const REACH_DIRECT := 0.05
const REACH_CLOSE := 0.10
const REACH_APPROX := 0.20

## Library cases: [family, partial, twin ("" none), weapon profile of the base, idle end, note].
const LIB_CASES := [
	["bow", "actor_b-p-bow-draw-grab^idle--part", "actor_b-p-bow-draw-grab^idle--add", "bow", "end", "graph bow equip (draw from the stow point to the carry)"],
	["bow", "actor_b-p-bow-draw-idle^grab--part", "actor_b-p-bow-draw-idle^grab--add", "bow", "start", "graph bow grab (reach to the stow point)"],
	["bow", "actor_b-p-bow-stow-grab^idle--part", "actor_b-p-bow-stow-grab^idle--add", "bow", "end", "graph bow crouch holster_finish (empty hand back from the stow point)"],
	["bow_reload", "actor_b-p-bow-reload--part", "actor_b-p-bow-reload--add", "bow", "end", "graph bow nock / Frontier grab: starts with the right hand at the quiver behind the right shoulder, pulls the arrow up and nocks it"],
	["bow_reload", "actor_b-p-crouch-bow-reload--part", "actor_b-p-crouch-bow-reload--add", "bow", "end", "graph bow crouch nock: starts at the quiver"],
	["bow_switch", "actor_b-p-bow-aim-switch-high", "", "bow", "none", "bow passed between hands while aiming (stand)"],
	["bow_switch", "actor_b-p-bow-aim-switch-low", "", "bow", "none", "bow passed between hands while aiming (crouch)"],
	["long_gun", "actor_b-lg-stealth-draw^idle--arm-r", "actor_b-lg-stealth-draw^idle--add", "musket", "end", "graph musket equip / holster (reversed)"],
	["long_gun", "actor_b-lg-stealth-idle^grab--arm-r", "actor_b-lg-stealth-idle^grab--add", "musket", "start", "graph musket grab (reach to the stow point)"],
	["long_gun", "actor_b-lg-stealth-stow^idle--arm-r", "actor_b-lg-stealth-stow^idle--add", "musket", "end", "graph musket holster_finish (empty hand back)"],
	["pistol", "actor_b-p-stealth-draw-p^idle--arm-r", "actor_b-p-crouch-draw-p^idle--add", "pistol", "end", "graph pistol equip / holster (reversed); twin = p-crouch-draw-p^idle--add data"],
	["pistol", "actor_b-p-crouch-idle^p-grab--arm-r", "actor_b-p-crouch-idle^p-grab--add", "pistol", "start", "graph pistol grab (stand and crouch)"],
	["pistol", "actor_b-p-stealth-stow-p^idle--arm-r", "actor_b-p-crouch-stow-p^idle--add", "pistol", "end", "graph pistol holster_finish (sprint / crouch)"],
	["pistol_no_pack", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack", "actor_b-p-stealth-draw-p^idle--add--no-pack", "pistol", "end", "backpack-off overlay variant of the pistol draw"],
	["pistol_no_pack", "actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "actor_b-p-stealth-idle^p-grab--add--no-pack", "pistol", "start", "backpack-off variant of the pistol grab"],
	["pistol_no_pack", "actor_b-p-stealth-stow-p^idle--arm-r--no-pack", "actor_b-p-stealth-stow-p^idle--add--no-pack", "pistol", "end", "backpack-off variant of the pistol stow"],
	["pistol_pack", "actor_b-pistol-pack-unholster--part", "actor_b-pistol-pack-unholster--add", "pistol", "end", "pistol from the pack"],
	["pistol_pack", "actor_b-pistol-pack-holster--part", "actor_b-pistol-pack-holster--add", "pistol", "start", "pistol into the pack"],
	["throwable", "actor_b-p-molotov-draw^idle--part", "actor_b-p-molotov-draw^idle--add", "pistol", "end", "graph molotov-pack-draw: one-hand object drawn into the hand"],
	["throwable", "actor_b-p-molotov-idle^draw--part", "actor_b-p-molotov-idle^draw--add", "pistol", "start", "one-hand object put away"],
	["throwable", "actor_b-p-1h-aim-throw-switch-high", "", "pistol", "none", "object passed between hands while aiming (stand)"],
	["throwable", "actor_b-p-1h-aim-throw-switch-low", "", "pistol", "none", "object passed between hands while aiming (crouch)"],
	["switch_hands", "actor_b-p-switch-hands-knife", "", "pistol", "none", "gun-switch-hands-stand-p -> p-switch-hands-pistol (same data as p-switch-hands-knife)"],
	["switch_hands", "actor_b-p-switch-hands-pistol-crouch", "", "pistol", "none", "gun-switch-hands-crouch-p"],
	["switch_hands", "actor_b-p-switch-hands-rifle-stand", "", "musket", "none", "gun-switch-hands-stand-lg / crouch-lg"],
	["switch_hands", "actor_b-p-switch-hands-rifle-crouch", "", "musket", "none", "rifle switch hands, crouch"],
	["switch_hands", "actor_b-p-switch-hands-knife-crouch", "", "pistol", "none", "wp-switch-hands-crouch-machete"],
	["switch_hands", "actor_b-p-switch-hands-knife-cover-crouch", "", "pistol", "none", "knife switch hands in low cover"],
	["switch_hands", "actor_b-p-switch-hands-obj", "", "pistol", "none", "object switch hands (cover)"],
	["switch_hands", "actor_b-p-switch-hands-molotov", "", "pistol", "none", "molotov / smoke switch hands (cover high)"],
	["switch_hands", "actor_b-p-switch-hands-smoke", "", "pistol", "none", "smoke switch hands (cover low)"],
	["switch_hands", "actor_b-p-switch-hands-nail", "", "pistol", "none", "nail bomb switch hands"],
	["switch_hands", "actor_b-p-switch-hands-beer", "", "pistol", "none", "bottle switch hands"],
	["switch_hands", "actor_b-p-switch-hands-medkit", "", "pistol", "none", "bandage switch hands"],
	["switch_hands", "actor_b-p-cover-low-switch-hands-gun-idle--part", "", "pistol", "none", "cover-low into left^right (pistol)"],
	["switch_hands", "actor_b-p-cover-low-switch-hands-knife-idle--part", "", "pistol", "none", "cover-low into left^right (one-hand weapon)"],
	["switch_hands", "actor_b-p-cover-high-switch-hands-knife-idle--part", "", "pistol", "none", "cover-high switch (one-hand weapon)"],
	["pack", "actor_b-p-stealth-backpack--part", "actor_b-p-stealth-backpack--add", "pistol", "none", "stash an item in the pack"],
	["pack", "actor_b-p-stealth-backpack-rhand--part", "actor_b-p-stealth-backpack-rhand--add", "pistol", "none", "stash, right hand"],
	["pack", "actor_b-p-stealth-backpack-shoulder--part", "actor_b-p-stealth-backpack-shoulder--add", "pistol", "none", "stash over the shoulder"],
	["pack", "actor_b-p-stealth-backpack-heavy--part", "actor_b-p-stealth-backpack-heavy--add", "pistol", "none", "stash a heavy item"],
	["strap", "actor_b-fist-ambi-flashlight-draw--part", "actor_b-fist-ambi-flashlight-draw--add", "pistol", "none", "flashlight taken from the strap (left hand; the source's flashlight hangs on the left chest strap)"],
	["strap", "actor_b-fist-ambi-flashlight-holster-part", "actor_b-fist-ambi-flashlight-holster--add", "pistol", "none", "flashlight put back on the strap"],
	["climb_weapon", "actor_b-p-idle-jump-up-2m^ledge-chest-mid-rifle--part", "", "musket", "none", "ledge climb arms with the rifle out (info: source climbs keep long guns in hand)"],
	["climb_weapon", "actor_b-p-idle-jump-up-2m^ledge-chest-mid-bow--part", "", "bow", "none", "ledge climb arms with the bow out"],
]
## Locomotion clips for the stow-parent drift check (full body, played alone).
const DRIFT_CLIPS := ["actor_b-p-relax-idle", "actor_b-p-walk-fw", "actor_b-p-run-fw", "actor_b-p-sprint-fw",
		"actor_b-p-idle^run-fw", "actor_b-p-crouch-idle", "actor_b-p-crouch-walk-fw", "actor_b-p-jump-long",
		"actor_b-p-land-soft^run"]
## Right-hand cases also evaluated mirrored (left hand, left side).
const MIRROR := ["actor_b-p-stealth-draw-p^idle--arm-r", "actor_b-p-crouch-idle^p-grab--arm-r",
		"actor_b-p-stealth-stow-p^idle--arm-r", "actor_b-p-molotov-draw^idle--part",
		"actor_b-lg-stealth-draw^idle--arm-r", "actor_b-pistol-pack-unholster--part",
		"actor_b-fist-ambi-flashlight-draw--part", "actor_b-p-stealth-draw-p^idle--arm-r--no-pack",
		"actor_b-p-stealth-idle^p-grab--arm-r--no-pack", "actor_b-p-stealth-stow-p^idle--arm-r--no-pack"]

var _args := {}
var sk: Skeleton3D
var ap: AnimationPlayer
var inst: Node3D
var lib: AnimationLibrary
var nb := 0
var names := PackedStringArray()
var idx := {}
var parent := PackedInt32Array()
var partner := PackedInt32Array()
var depth := PackedInt32Array()
var rest: Array[Transform3D] = []
var rest_g: Array[Transform3D] = []
var rest_q: Array[Quaternion] = []
var rest_p := PackedVector3Array()
var rest_s := PackedVector3Array()
var mir: Array[Transform3D] = []
var mir_root := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
var closure := PackedInt32Array()
var graph := {}
var errors: Array[String] = []
var warnings: Array[String] = []
var _base_cache := {}
var _clip_cache := {}
var _val_worst := 0.0
var _val_where := ""
var _val_n := 0
## Belt ring (bind pose): centre (x, z) and surface radius per BELT_STEP_DEG azimuth from -180.
var _ring_c := Vector2.ZERO
var _ring_r := PackedFloat64Array()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			_args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1)
		else:
			_args[s] = true
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	var out_path := String(_args.get("out", DEFAULT_OUT))
	var doc := {}
	var ok := false
	if _setup():
		doc = _measure()
		ok = errors.is_empty()
		if not doc.is_empty():
			# summary (indented) + every case in full (compact) next to it
			var cases_path := out_path.get_basename() + "_cases.json"
			var cases: Dictionary = doc.cases
			doc.erase("cases")
			doc.meta.cases_file = cases_path.get_file()
			doc.meta.case_ids = cases.keys()
			var detail := {"meta": {"schema": SCHEMA, "generator": GENERATOR, "summary_file": out_path.get_file(),
					"axes": doc.meta.axes}, "cases": cases}
			for pair in [[out_path, JSON.stringify(_round(doc), " ", true)], [cases_path, JSON.stringify(_round(detail), "", true)]]:
				var f := FileAccess.open(pair[0], FileAccess.WRITE)
				if f == null:
					errors.append("cannot write " + pair[0])
					ok = false
					continue
				f.store_string(pair[1] + "\n")
				f.close()
			doc.cases = cases
	for w in warnings:
		print("WARN ", w)
	for e in errors:
		printerr("ERROR ", e)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	if ok:
		print("HANDOFFS OK: %d cases, validation max %.3f mm (%s), %.1f s -> %s" % [
				(doc.get("cases", {}) as Dictionary).size(), _val_worst * 1000.0, _val_where, secs, out_path])
	else:
		print("HANDOFFS FAILED (%d errors)" % errors.size())
	quit(0 if ok else 1)


# --- rig ----------------------------------------------------------------------------------------

func _setup() -> bool:
	var ps: PackedScene = load(RIG)
	if ps == null:
		errors.append("cannot load " + RIG)
		return false
	inst = ps.instantiate()
	root.add_child(inst)
	sk = inst.get_node("Skeleton3D")
	ap = inst.get_node("AnimationPlayer")
	lib = ap.get_animation_library(LIB)
	if sk == null or ap == null or lib == null:
		errors.append("rig without Skeleton3D / AnimationPlayer / library " + LIB)
		return false
	var br := _ensure_rest()
	if not bool(br.get("ok", false)):
		errors.append("BindRest: " + str(br))
		return false
	nb = sk.get_bone_count()
	for b in nb:
		names.append(sk.get_bone_name(b))
		idx[sk.get_bone_name(b)] = b
		parent.append(sk.get_bone_parent(b))
		var r := sk.get_bone_rest(b)
		rest.append(r)
		rest_q.append(r.basis.get_rotation_quaternion())
		rest_p.append(r.origin)
		rest_s.append(r.basis.get_scale())
	for b in nb:
		var d := 0
		var p := parent[b]
		while p >= 0:
			d += 1
			p = parent[p]
		depth.append(d)
	var order := range(nb)
	order.sort_custom(func(x, y): return depth[x] < depth[y] or (depth[x] == depth[y] and x < y))
	rest_g.resize(nb)
	for b in order:
		rest_g[b] = rest_g[parent[b]] * rest[b] if parent[b] >= 0 else rest[b]
	for b in nb:
		var n := names[b]
		var o := b
		if n.begins_with("l_"):
			o = int(idx.get("r_" + n.substr(2), b))
		elif n.begins_with("r_"):
			o = int(idx.get("l_" + n.substr(2), b))
		partner.append(o)
	var asym := []
	mir.resize(nb)
	for b in nb:
		mir[b] = rest_g[partner[b]].affine_inverse() * mir_root * rest_g[b]
		var p := parent[b]
		var pp := parent[partner[b]]
		if (p < 0) != (pp < 0) or (p >= 0 and partner[p] != pp):
			asym.append(names[b])
	if not asym.is_empty():
		warnings.append("mirror: %d bones whose partner has a non-mirrored parent: %s" % [asym.size(), str(asym.slice(0, 8))])
	var tracked := PackedInt32Array()
	for n in TRACKED:
		if not idx.has(n):
			errors.append("rig has no bone " + n)
			return false
		tracked.append(idx[n])
	closure = _closure(tracked)
	var txt := FileAccess.get_file_as_string(GRAPH)
	var g: Variant = JSON.parse_string(txt)
	if not g is Dictionary:
		errors.append("cannot parse " + GRAPH)
		return false
	graph = g
	return true


func _ensure_rest() -> Dictionary:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == &"BindRest":
			var s: Script = load(c["path"])
			if s:
				return s.call("ensure", sk, ap, StringName(LIB))
	return {"ok": false, "reason": "BindRest (scripts/player/anim/bind_rest.gd) not found; run Godot --import"}


func _closure(bones: PackedInt32Array) -> PackedInt32Array:
	var seen := {}
	for b in bones:
		var p := b
		while p >= 0 and not seen.has(p):
			seen[p] = true
			p = parent[p]
	var arr := seen.keys()
	arr.sort_custom(func(x, y): return depth[x] < depth[y] or (depth[x] == depth[y] and x < y))
	return PackedInt32Array(arr)


# --- clips --------------------------------------------------------------------------------------

class Clip:
	var name := ""
	var a: Animation
	var length := 0.0
	## bone -> PackedInt32Array [position, rotation, scale] track (-1 = not keyed)
	var tracks := {}
	var additive := false
	var asset_id := ""
	var sample_rate := 0.0
	var sample_count := 0

	func keyed() -> PackedInt32Array:
		var k := PackedInt32Array(tracks.keys())
		k.sort()
		return k

	## Local transform of bone b at time t (rest where a channel is not keyed).
	func local(b: int, t: float, r: Transform3D) -> Transform3D:
		var m: PackedInt32Array = tracks[b]
		var pos := a.position_track_interpolate(m[0], t) if m[0] >= 0 else r.origin
		var rot := a.rotation_track_interpolate(m[1], t).normalized() if m[1] >= 0 else r.basis.get_rotation_quaternion()
		var scl := a.scale_track_interpolate(m[2], t) if m[2] >= 0 else r.basis.get_scale()
		return Transform3D(Basis(rot) * Basis.from_scale(scl), pos)


func _clip(name: String) -> Clip:
	if _clip_cache.has(name):
		return _clip_cache[name]
	var c: Clip = null
	if lib.has_animation(name):
		c = Clip.new()
		c.name = name
		c.a = lib.get_animation(name)
		c.length = c.a.length
		c.additive = bool(c.a.get_meta("additive_source", false)) if c.a.has_meta("additive_source") else name.contains("--add")
		c.asset_id = String(c.a.get_meta("native_asset_id", "")) if c.a.has_meta("native_asset_id") else ""
		c.sample_rate = float(c.a.get_meta("sample_rate", 0.0)) if c.a.has_meta("sample_rate") else 0.0
		c.sample_count = int(c.a.get_meta("sample_count", 0)) if c.a.has_meta("sample_count") else 0
		for t in c.a.get_track_count():
			var slot := -1
			match c.a.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					slot = 0
				Animation.TYPE_ROTATION_3D:
					slot = 1
				Animation.TYPE_SCALE_3D:
					slot = 2
			if slot < 0:
				continue
			var b: int = idx.get(str(c.a.track_get_path(t).get_concatenated_subnames()), -1)
			if b < 0:
				continue
			if not c.tracks.has(b):
				c.tracks[b] = PackedInt32Array([-1, -1, -1])
			var m: PackedInt32Array = c.tracks[b]
			m[slot] = t
			c.tracks[b] = m
	_clip_cache[name] = c
	return c


# --- base pose (scratch AnimationTree) ------------------------------------------------------------

## Base role of a weapon profile / stance: {clip, layers: [{clip, weight, additive}], key}.
func _base_role(w: String, stance: String) -> Dictionary:
	var key := "%s/%s/idle" % [w, STANCE_MODE[stance]]
	var roles: Dictionary = graph.get("roles", {})
	var r: Dictionary = roles.get(key, {})
	var out := {"role": "roles." + key, "clip": String(r.get("clip", "actor_b-p-relax-idle" if stance == "stand" else "actor_b-p-crouch-idle")), "layers": []}
	for l in r.get("layers", []):
		if not l.get("clip") is String or _clip(String(l.clip)) == null:
			continue
		out.layers.append({"clip": String(l.clip), "weight": float(l.get("weight", 1.0)),
				"additive": String(l.get("kind", "")) == "additive" or _clip(String(l.clip)).additive, "slot": l.get("slot")})
	return out


func _anim_node(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = StringName(LIB + "/" + clip)
	return n


func _filter(node: AnimationNodeBlend2, c: Clip) -> void:
	node.filter_enabled = true
	for b in c.keyed():
		node.set_filter_path(NodePath("Skeleton3D:" + names[b]), true)


## Scratch tree: base + layers [+ Blend2(partial) + Add2(twin), both behind TimeSeek nodes].
func _tree(base: Dictionary, partial: Clip, twin: Clip) -> AnimationTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", _anim_node(base.clip))
	var last := "base"
	var amounts := {}
	var i := 0
	for l in base.layers:
		var n := "L%d" % i
		bt.add_node("C%d" % i, _anim_node(l.clip))
		if l.additive:
			bt.add_node(n, AnimationNodeAdd2.new())
			amounts["parameters/%s/add_amount" % n] = l.weight
		else:
			var b2 := AnimationNodeBlend2.new()
			_filter(b2, _clip(l.clip))
			bt.add_node(n, b2)
			amounts["parameters/%s/blend_amount" % n] = l.weight
		bt.connect_node(n, 0, last)
		bt.connect_node(n, 1, "C%d" % i)
		last = n
		i += 1
	if partial:
		bt.add_node("PA", _anim_node(partial.name))
		bt.add_node("PS", AnimationNodeTimeSeek.new())
		bt.connect_node("PS", 0, "PA")
		var p2 := AnimationNodeBlend2.new()
		_filter(p2, partial)
		bt.add_node("P", p2)
		bt.connect_node("P", 0, last)
		bt.connect_node("P", 1, "PS")
		amounts["parameters/P/blend_amount"] = 1.0
		last = "P"
	if twin:
		bt.add_node("TA", _anim_node(twin.name))
		bt.add_node("TS", AnimationNodeTimeSeek.new())
		bt.connect_node("TS", 0, "TA")
		bt.add_node("T", AnimationNodeAdd2.new())
		bt.connect_node("T", 0, last)
		bt.connect_node("T", 1, "TS")
		amounts["parameters/T/add_amount"] = 1.0
		last = "T"
	bt.connect_node("output", 0, last)
	sk.reset_bone_poses()
	var tree := AnimationTree.new()
	tree.name = "HandoffTree"
	inst.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(inst)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.deterministic = true
	tree.tree_root = bt
	tree.active = true
	for k in amounts:
		tree.set(k, amounts[k])
	tree.advance(0.0)
	tree.advance(0.0)
	return tree


func _drop(tree: AnimationTree) -> void:
	tree.active = false
	inst.remove_child(tree)
	tree.free()
	sk.reset_bone_poses()


## Local pose components of the base (clip at t = 0 plus layers), cached per role.
func _base_pose(base: Dictionary) -> Dictionary:
	var key := JSON.stringify([base.clip, base.layers])
	if _base_cache.has(key):
		return _base_cache[key]
	var tree := _tree(base, null, null)
	var P := PackedVector3Array()
	var S := PackedVector3Array()
	var Q: Array[Quaternion] = []
	for b in nb:
		P.append(sk.get_bone_pose_position(b))
		Q.append(sk.get_bone_pose_rotation(b))
		S.append(sk.get_bone_pose_scale(b))
	_drop(tree)
	var d := {"p": P, "q": Q, "s": S}
	_base_cache[key] = d
	return d


# --- manual composition ---------------------------------------------------------------------------

func _mirror_local(b: int, l_src: Transform3D) -> Transform3D:
	var fp: Transform3D = mir[parent[b]] if parent[b] >= 0 else mir_root
	return fp.affine_inverse() * l_src * mir[b]


## Skeleton-space transforms of the closure bones at partial time tp / twin time tt.
func _pose(base: Dictionary, partial: Clip, tp: float, twin: Clip, tt: float, mirrored: bool) -> Dictionary:
	var P: PackedVector3Array = base.p.duplicate()
	var Q: Array = base.q.duplicate()
	var S: PackedVector3Array = base.s.duplicate()
	if partial:
		for k in partial.tracks:
			var b: int = partner[k] if mirrored else k
			var L := partial.local(k, tp, rest[k])
			if mirrored:
				L = _mirror_local(b, L)
			P[b] = L.origin
			S[b] = L.basis.get_scale()
			Q[b] = L.basis.orthonormalized().get_rotation_quaternion()
	if twin:
		for k in twin.tracks:
			var b: int = partner[k] if mirrored else k
			var A := twin.local(k, tt, rest[k])
			if mirrored:
				A = _mirror_local(b, A)
			var aq := A.basis.orthonormalized().get_rotation_quaternion()
			var m: PackedInt32Array = twin.tracks[k]
			if m[1] >= 0:
				Q[b] = (Q[b] * (rest_q[b].inverse() * aq)).normalized()
			if m[0] >= 0:
				P[b] = P[b] + (A.origin - rest_p[b])
			if m[2] >= 0:
				S[b] = S[b] + (A.basis.get_scale() - rest_s[b])
	var G := {}
	for b in closure:
		var L := Transform3D(Basis(Q[b]) * Basis.from_scale(S[b]), P[b])
		G[b] = (G[parent[b]] as Transform3D) * L if parent[b] >= 0 else L
	return G


# --- body carry points ----------------------------------------------------------------------------

## Belt ring and chest points on the default body (bind pose = rig rest, skeleton space).
func _targets() -> Dictionary:
	var out := {"source": BODY, "belt": [], "chest": [], "notes": [], "belt_mid_y": BELT_MID_Y}
	var belt := PackedVector3Array()
	var coat := PackedVector3Array()
	var ps: PackedScene = load(BODY) if ResourceLoader.exists(BODY) else null
	if ps:
		var body := ps.instantiate()
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			if m == null:
				continue
			for s in m.get_surface_count():
				var mat := m.surface_get_material(s)
				var mname := mat.resource_name if mat else ""
				if mname == "":
					mname = m.surface_get_name(s)
				if not mname in ["belt", "coat", "waistcoat"]:
					continue
				var arr := m.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				if mname == "belt":
					belt.append_array(v)
				else:
					coat.append_array(v)
		body.free()
	else:
		warnings.append("targets: %s not loadable; analytic fallback" % BODY)
	var pelvis_b: int = idx["pelvis"]
	var spinec_b: int = idx["spinec"]
	# belt ring
	var cx := 0.0
	var cz := 0.0
	var ymin := INF
	var ymax := -INF
	for p in belt:
		cx += p.x
		cz += p.z
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	var have_belt := belt.size() > 50
	if have_belt:
		cx /= belt.size()
		cz /= belt.size()
		out.belt_band_y = [ymin, ymax]
	else:
		out.notes.append("belt band not found in the body mesh: ellipse 0.165 x 0.125 m fallback")
	out.belt_centre_xz = [cx, cz]
	var n_az := int(round(360.0 / BELT_STEP_DEG))
	var circ := 0.0
	var prev := Vector3.INF
	var first := Vector3.INF
	for i in n_az:
		var az := -180.0 + i * BELT_STEP_DEG
		var th := deg_to_rad(az)
		var dirv := Vector3(sin(th), 0.0, cos(th))
		var r := 0.0
		if have_belt:
			for p in belt:
				var dx := p.x - cx
				var dz := p.z - cz
				var a := rad_to_deg(atan2(dx, dz))
				if absf(wrapf(a - az, -180.0, 180.0)) <= BELT_STEP_DEG * 0.5:
					r = maxf(r, sqrt(dx * dx + dz * dz))
		else:
			r = 1.0 / sqrt(pow(sin(th) / 0.165, 2) + pow(cos(th) / 0.125, 2))
		var surf := Vector3(cx, BELT_MID_Y, cz) + dirv * r
		if prev != Vector3.INF:
			circ += surf.distance_to(prev)
		else:
			first = surf
		prev = surf
		var pts := []
		for bulk in BULK:
			var g: Vector3 = surf + dirv * (GRIP_OUT + float(bulk)) + Vector3.UP * GRIP_UP
			pts.append({"bulk_m": bulk, "skel": g, "pelvis": rest_g[pelvis_b].affine_inverse() * g})
		out.belt.append({"az_deg": az, "side": _az_label(az), "surface": surf, "radius_m": r, "grip": pts})
	circ += prev.distance_to(first)
	out.belt_circumference_m = circ
	_ring_c = Vector2(cx, cz)
	_ring_r.clear()
	for e in out.belt:
		_ring_r.append(float(e.radius_m))
	# chest: the outermost of coat / waistcoat (the frock is open in front)
	for y in CHEST_Y:
		for az in CHEST_AZ:
			var th := deg_to_rad(az)
			var dirv := Vector3(sin(th), 0.0, cos(th))
			var best := Vector3.INF
			var bestr := 0.0
			for p in coat:
				if absf(p.y - y) > 0.02 or p.z < 0.0:
					continue
				var a := rad_to_deg(atan2(p.x, p.z))
				if absf(a - az) <= 7.5:
					var r := Vector2(p.x, p.z).length()
					if r > bestr:
						bestr = r
						best = p
			if best == Vector3.INF:
				out.notes.append("chest: no coat vertex near y %.2f az %.0f" % [y, az])
				continue
			var surf := Vector3(best.x, y, best.z)
			var pts := []
			for bulk in BULK:
				var g: Vector3 = surf + dirv * (GRIP_OUT + float(bulk))
				pts.append({"bulk_m": bulk, "skel": g, "spinec": rest_g[spinec_b].affine_inverse() * g})
			out.chest.append({"y": y, "az_deg": az, "side": _az_label(az), "surface": surf, "grip": pts})
	# the body's current powder horn (tools/character/build_body.py horn_node(), Blender (x, y, z) -> (x, z, -y))
	out.powder_horn_now = {"base": Vector3(-0.207, 0.905, -0.085), "middle": Vector3(-0.222, 0.866, 0.0),
			"spout": Vector3(-0.200, 0.900, 0.070), "note": "horn_node() Bezier control points; rigid on the pelvis"}
	return out


static func _az_label(az: float) -> String:
	var a := wrapf(az, -180.0, 180.0)
	if absf(a) <= 22.5:
		return "front"
	if absf(a) >= 157.5:
		return "back"
	var side := "left" if a > 0.0 else "right"
	var m := absf(a)
	if m < 67.5:
		return "front-" + side
	if m <= 112.5:
		return side + " hip"
	return "back-" + side


# --- measurement --------------------------------------------------------------------------------

func _measure() -> Dictionary:
	var timings := _weapon_timings()
	var targets := _targets()
	var cases := {}
	var only := String(_args.get("only", ""))
	var specs := _case_specs()
	for spec in specs:
		if only != "" and not String(spec.id).contains(only):
			continue
		var r := _run_case(spec, targets, timings)
		if not r.is_empty():
			cases[spec.id] = r
	var doc := {
		"meta": {
			"schema": SCHEMA, "generator": GENERATOR, "godot_version": Engine.get_version_info().string,
			"rig": RIG, "library": LIB, "graph": GRAPH, "body": BODY,
			"axes": "skeleton space: +Z = character forward, +X = character LEFT, +Y = up; metres, seconds",
			"sample_hz": HZ,
			"composition": "base = roles.<w>/<run|crouch>/idle clip at t = 0 + its layers (scratch AnimationTree); partial replaces its keyed bones (prop bones included); twin Add2 at 1 (phase-matched); FK",
			"grab_rule": "junction frame by the source naming (A^B = from A to B): X^idle -> first frame, idle^X -> last frame (the graph's grab <-> draw seam, where the game moves the gun between holster and hand: the draw leaf is p-grab^idle-GUNOUT); gestures (switch hands, reload, pack stash) -> the frame farthest from the carry pose among frames with speed <= max(%.1f x peak, %.2f m/s). hands.*.arrival = slowest frame on the grab side (first / last 40 %%), a cross-check" % [SLOW_REL, SLOW_ABS],
			"model_offset": "model = prop * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) (Frontier socket offset; prop +Z = barrel / point)",
			"mirror": "M: cases reflect every keyed local transform of the clip through the sagittal plane (L' = F(parent)^-1 L(partner) F(b), F(b) = G_rest(partner)^-1 diag(-1,1,1) G_rest(b)) over the unmirrored base",
			"reach_verdicts_m": {"direct": REACH_DIRECT, "close": REACH_CLOSE, "approx": REACH_APPROX},
			"validation": {"max_prop_err_mm": _val_worst * 1000.0, "worst": _val_where, "samples": _val_n,
					"what": "manual composition vs a full AnimationTree (Blend2 filtered partial + Add2 twin behind TimeSeek) at phases 0, 0.5, 1 of every case"},
			"warnings": warnings,
		},
		"rest": _rest_info(),
		"targets": targets,
		"weapon_timings": timings,
		"cases": cases,
	}
	doc.graph_actions = _graph_summary(cases)
	doc.sequences = _sequences(cases)
	doc.belt_reach = _belt_reach_table(cases, targets)
	doc.multi_pistol = _multi_pistol(cases, targets)
	doc.throwables = _throwable_summary(cases, targets)
	doc.unarmed = _unarmed_summary()
	doc.parent_drift = _parent_drift(targets)
	doc.stow_points = _stow_points(cases)
	for k in ["graph_actions", "sequences", "belt_reach", "multi_pistol", "throwables", "unarmed", "parent_drift", "stow_points"]:
		var v: Variant = doc.get(k)
		if v == null or ((v is Dictionary or v is Array) and v.is_empty()):
			errors.append("summary '%s' is empty (script error above?)" % k)
	doc.meta.validation = {"max_prop_err_mm": _val_worst * 1000.0, "worst": _val_where, "samples": _val_n,
			"what": "manual composition vs a full AnimationTree (Blend2 filtered partial + Add2 twin behind TimeSeek) at phases 0, 0.5, 1 of every unmirrored case"}
	if _val_worst > 0.002:
		errors.append("validation: manual composition differs from the AnimationTree by %.2f mm (%s)" % [_val_worst * 1000.0, _val_where])
	return doc


func _weapon_timings() -> Dictionary:
	var want := {"bow": "Bow", "musket": "Musket", "pistol": "FlintlockPistol", "spear": "ThrowableSpear",
			"tomahawk": "ThrowableTomahawk", "atlatl": "ThrowableAtlatl"}
	var paths := {}
	for c in ProjectSettings.get_global_class_list():
		paths[String(c["class"])] = String(c["path"])
	var out := {}
	for k in want:
		var cls: String = want[k]
		if not paths.has(cls):
			warnings.append("timings: class %s not found" % cls)
			continue
		var s: Script = load(paths[cls])
		var o: Object = s.new() if s else null
		if o == null:
			continue
		var d := {"class": cls, "script": paths[cls]}
		for p in ["equip_time", "draw_time", "grab_time", "nock_time", "hand_nock_time"]:
			var v: Variant = o.get(p)
			if v != null:
				d[p] = v
		out[k] = d
		if o is Node:
			(o as Node).free()
	return out


## Case list: graph actions (weapon x stance x key) and library clips (x stance), plus mirrored ones.
func _case_specs() -> Array:
	var specs := []
	var acts: Dictionary = graph.get("actions", {})
	for w in ["bow", "musket", "pistol"]:
		for st in ["stand", "crouch"]:
			for key in ["grab", "equip", "holster", "holster_finish"]:
				var ak := "%s/%s/%s" % [w, st, key]
				if not acts.has(ak):
					warnings.append("graph action %s missing" % ak)
					continue
				var a: Dictionary = acts[ak]
				var end := "start" if key == "grab" else "end"
				specs.append({"id": "graph:" + ak, "family": "graph_" + w, "partial": String(a.get("partial", "")),
						"twin": String(a.get("twin", "")) if a.get("twin") is String else "", "weapon": w, "stance": st,
						"idle_end": end, "note": "graph action", "graph_key": ak, "mirrored": false})
	for c in LIB_CASES:
		for st in ["stand", "crouch"]:
			var id := "clip:%s@%s" % [c[1], st]
			specs.append({"id": id, "family": c[0], "partial": c[1], "twin": c[2], "weapon": c[3], "stance": st,
					"idle_end": c[4], "note": c[5], "mirrored": false})
			if c[1] in MIRROR:
				specs.append({"id": "M:" + id, "family": c[0], "partial": c[1], "twin": c[2], "weapon": c[3], "stance": st,
						"idle_end": c[4], "note": "MIRRORED (left hand, left side): " + c[5], "mirrored": true})
	return specs


func _run_case(spec: Dictionary, targets: Dictionary, timings: Dictionary) -> Dictionary:
	var partial: Clip = _clip(spec.partial) if spec.partial != "" else null
	var twin: Clip = _clip(spec.twin) if spec.twin != "" else null
	if partial == null:
		warnings.append("%s: clip %s not in the library; skipped" % [spec.id, spec.partial])
		return {}
	if spec.twin != "" and twin == null:
		warnings.append("%s: twin %s not in the library; measured without it" % [spec.id, spec.twin])
	var base := _base_role(spec.weapon, spec.stance)
	var bp := _base_pose(base)
	var mirrored: bool = spec.mirrored
	var n := maxi(2, int(ceil(partial.length * HZ)) + 1)
	var times := PackedFloat64Array()
	for i in n:
		times.append(minf(i / HZ, partial.length))
	var poses := []
	for t in times:
		var tt := 0.0
		if twin and partial.length > 0.0:
			tt = t / partial.length * twin.length
		poses.append(_pose(bp, partial, t, twin, tt, mirrored))
	if not mirrored:
		_validate(spec.id, base, bp, partial, twin)
	var res := {"family": spec.family, "clip": partial.name, "twin": twin.name if twin else null, "stance": spec.stance,
			"weapon_profile": spec.weapon, "note": spec.note, "mirrored": mirrored,
			"base": {"role": base.role, "clip": base.clip, "layers": base.layers.map(func(l): return [l.clip, l.weight, "add" if l.additive else "blend"])},
			"length_s": partial.length, "twin_length_s": twin.length if twin else null,
			"sample_rate": partial.sample_rate, "sample_count": partial.sample_count,
			"native_asset_id": {"partial": partial.asset_id, "twin": twin.asset_id if twin else null},
			"idle_end": spec.idle_end}
	var kb := partial.keyed()
	var arms := {"r": false, "l": false}
	var props := []
	for k in kb:
		var b: int = partner[k] if mirrored else k
		var nm := names[b]
		if nm.begins_with("r_") and (nm.contains("wrist") or nm.contains("elbow")):
			arms.r = true
		if nm.begins_with("l_") and (nm.contains("wrist") or nm.contains("elbow")):
			arms.l = true
		if nm.ends_with("_hand_prop_attachment"):
			props.append(nm)
	res.keyed_bones = kb.size()
	res.arms_keyed = arms
	res.prop_keyed = props
	var hands := {}
	for h in ["r", "l"]:
		hands[h] = _hand_track(poses, times, h, spec.idle_end, targets, partial.sample_rate)
	res.hands = hands
	var act := "r"
	if arms.r and not arms.l:
		act = "r"
	elif arms.l and not arms.r:
		act = "l"
	elif float(hands.l.grab_side_path_m) > float(hands.r.grab_side_path_m):
		act = "l"
	res.active_hand = act
	res.handoff = {}
	for h in ["r", "l"]:
		var g: Dictionary = hands[h].grab
		res.handoff[h] = _handoff(poses[int(g.i)], h, g)
		if int(g.parked_i) >= 0:
			res.handoff[h].parked = _parked(poses[int(g.parked_i)], h, times[int(g.parked_i)])
	# both prop bones at the active hand's grab frame (two-hand weapons key both on the weapon; the
	# Frontier model hangs on its weapon hand's prop) and at its parked key, with the parked -> in-hand jump
	var ga: Dictionary = hands[act].grab
	res.props_at_grab = {"t": ga.t, "r": _parked(poses[int(ga.i)], "r", ga.t), "l": _parked(poses[int(ga.i)], "l", ga.t)}
	if int(ga.parked_i) >= 0:
		var pi := int(ga.parked_i)
		res.props_parked = {"t": times[pi], "r": _parked(poses[pi], "r", times[pi]), "l": _parked(poses[pi], "l", times[pi]), "jump_to_grab": {}}
		for h2 in ["r", "l"]:
			var a0: Transform3D = poses[pi][idx[PROP[h2]]]
			var a1: Transform3D = poses[int(ga.i)][idx[PROP[h2]]]
			var dq := a0.basis.orthonormalized().get_rotation_quaternion().inverse() * a1.basis.orthonormalized().get_rotation_quaternion()
			res.props_parked.jump_to_grab[h2] = {"pos_m": a0.origin.distance_to(a1.origin),
					"rot_deg": rad_to_deg(2.0 * acos(clampf(absf(dq.normalized().w), 0.0, 1.0)))}
	# closest approach of the two prop bones (hand-to-hand passes)
	var dmin := INF
	var tmin := 0.0
	for i in poses.size():
		var d := (poses[i][idx[PROP.r]] as Transform3D).origin.distance_to((poses[i][idx[PROP.l]] as Transform3D).origin)
		if d < dmin:
			dmin = d
			tmin = times[i]
	res.hands_gap_min = {"d_m": dmin, "t": tmin, "phase": tmin / maxf(partial.length, 1e-6)}
	if spec.has("graph_key"):
		res.graph = _graph_playback(spec.graph_key, partial.length, hands[act].grab, timings)
	# drop the per-hand sample index (internal)
	for h in hands:
		(hands[h].grab as Dictionary).erase("i")
		(hands[h].grab as Dictionary).erase("parked_i")
	return res


## Path of one hand, its grab / release frame and its approach to the holster bones and carry points.
## The hand point is the palm carrying the prop bone's REST offset (where a held grip sits); the prop
## bone itself is keyed by many clips (two-hand weapons key both prop bones on the weapon; the bow
## reload keys the arrow), so it gives the stowed transform but not the hand's reach.
func _hand_track(poses: Array, times: PackedFloat64Array, h: String, idle_end: String, targets: Dictionary, key_rate: float) -> Dictionary:
	var n := poses.size()
	var kstep := maxi(1, int(round(HZ / key_rate))) if key_rate > 0.0 else 6
	var pb: int = idx[PROP[h]]
	var palm: int = idx[h + "_palm"]
	var P := PackedVector3Array()
	var off := PackedFloat64Array()
	var off_max := 0.0
	for i in n:
		var hp := ((poses[i][palm] as Transform3D) * rest[pb]).origin
		P.append(hp)
		var d := hp.distance_to((poses[i][pb] as Transform3D).origin)
		off.append(d)
		off_max = maxf(off_max, d)
	var v := PackedFloat64Array()
	v.resize(n)
	var path := 0.0
	var vmax := 0.0
	for i in n:
		var a := maxi(i - 1, 0)
		var b := mini(i + 1, n - 1)
		var dt := times[b] - times[a]
		v[i] = P[b].distance_to(P[a]) / dt if dt > 0.0 else 0.0
		vmax = maxf(vmax, v[i])
		if i > 0:
			path += P[i].distance_to(P[i - 1])
	# carry end: "X^idle" ends in the carry pose, "idle^X" starts in it, gestures start (and end) in it
	var ref := P[n - 1] if idle_end == "end" else P[0]
	var slow := maxf(SLOW_REL * vmax, SLOW_ABS)
	# prop transfers: the clip moves the prop bone between the body (parked) and the hand, or passes
	# it between the hands (two-hand weapons key both prop bones on the weapon)
	var other: String = "l" if h == "r" else "r"
	var opb: int = idx[PROP[other]]
	var opalm: int = idx[other + "_palm"]
	var transfers := []
	var on := off[0] <= PROP_ON
	for i in range(1, n):
		var was := on
		if on and off[i] >= PROP_OFF:
			on = false
		elif not on and off[i] <= PROP_ON:
			on = true
		if on != was:
			# attach: first frame in the hand; detach: last frame in the hand. The parked pose is read at
			# the clip's own keys on the parked side (between keys the prop's local transform is
			# interpolated under a moving palm, so it drifts even when the source parks it)
			var j := i if on else i - 1
			# the in-hand side snapped to the clip's key (the authored pose next to the parked key)
			var jk := mini(int(ceil(float(i) / kstep)) * kstep, n - 1) if on else int(floor(float(i - 1) / kstep)) * kstep
			var k1 := -1
			var k0 := -1
			if on:
				k1 = int(floor(float(i - 1) / kstep)) * kstep
				k0 = k1 - kstep
			else:
				k1 = int(ceil(float(i) / kstep)) * kstep
				k0 = k1 + kstep
			k1 = clampi(k1, 0, n - 1)
			var pk := (poses[k1][pb] as Transform3D).origin
			var oh := ((poses[k1][opalm] as Transform3D) * rest[opb]).origin
			# parked on the body: the prop rests (body frame) between the two keys on the parked side
			var fb := _anchor(poses[k1], pk)
			var drift := 0.0
			if k0 >= 0 and k0 < n:
				drift = _in_bind(poses[k0], (poses[k0][pb] as Transform3D).origin, fb).distance_to(_in_bind(poses[k1], pk, fb))
			var with := "body"
			if pk.distance_to(oh) <= PROP_OFF:
				with = "other_hand"
			elif drift > PARK_DRIFT:
				with = "in_flight"
			transfers.append({"kind": "attach" if on else "detach", "i": jk, "parked_i": k1, "t": times[j], "key_t": times[jk],
					"phase": times[j] / maxf(times[n - 1], 1e-6), "prop_offset_parked_m": off[k1],
					"with": with, "parked_drift_m": drift, "parked_key_t": times[k1]})
	# grab / release frame: a body transfer on this hand (the source moves the object between its
	# parked place on the body and the hand there; X^idle clips: first half, idle^X: second half);
	# else the junction (first frame of X^idle, last of idle^X: the graph's grab <-> draw seam); for
	# gestures the frame farthest from the carry pose among the slow frames
	var gi := -1
	var dbest := -1.0
	var rule := ""
	var parked_i := -1
	var body := transfers.filter(func(x): return x.with == "body" and (
			(idle_end == "end" and x.phase < 0.5) or (idle_end == "start" and x.phase > 0.5) or idle_end == "none"))
	if not body.is_empty():
		var pick: Dictionary = body[body.size() - 1] if idle_end == "start" else body[0]
		gi = int(pick.i)
		parked_i = int(pick.parked_i)
		rule = "prop transfer (%s, body): the clip moves the prop bone between its parked place and the hand; grab frame = the in-hand key next to the parked key" % pick.kind
	elif idle_end == "end":
		gi = 0
		rule = "junction: first frame (X^idle starts at the stow point)"
	elif idle_end == "start":
		gi = n - 1
		rule = "junction: last frame (idle^X ends at the stow point)"
	else:
		rule = "extreme: farthest from the carry pose among slow frames"
		for i in n:
			var d := P[i].distance_to(ref)
			if v[i] <= slow and d > dbest:
				dbest = d
				gi = i
		if gi < 0:
			rule = "extreme: farthest from the carry pose (no slow frame)"
			for i in n:
				var d := P[i].distance_to(ref)
				if d > dbest:
					dbest = d
					gi = i
	dbest = P[gi].distance_to(ref)
	# arrival cross-check: the slowest frame on the grab side (first / last 40 %, whole clip for gestures)
	var a0 := 0
	var a1 := n - 1
	if idle_end == "end":
		a1 = int(floor((n - 1) * 0.4))
	elif idle_end == "start":
		a0 = int(ceil((n - 1) * 0.6))
	var ai := a0
	for i in range(a0, a1 + 1):
		if v[i] < v[ai]:
			ai = i
	var gs_path := 0.0
	for i in range(maxi(a0, 1), a1 + 1):
		gs_path += P[i].distance_to(P[i - 1])
	# hold window around the grab frame
	var h0 := gi
	var h1 := gi
	while h0 > 0 and P[h0 - 1].distance_to(P[gi]) <= HOLD_TOL:
		h0 -= 1
	while h1 < n - 1 and P[h1 + 1].distance_to(P[gi]) <= HOLD_TOL:
		h1 += 1
	var length := times[n - 1]
	var grab := {"i": gi, "t": times[gi], "phase": times[gi] / maxf(length, 1e-6), "speed_mps": v[gi],
			"dist_from_carry_m": dbest, "hold": [times[h0], times[h1]], "rule": rule, "parked_i": parked_i,
			"hold_phase": [times[h0] / maxf(length, 1e-6), times[h1] / maxf(length, 1e-6)]}
	var arrival := {"t": times[ai], "phase": times[ai] / maxf(length, 1e-6), "speed_mps": v[ai],
			"dist_to_grab_m": P[ai].distance_to(P[gi]), "window": [times[a0], times[a1]]}
	var near := {}
	for hn in HOLSTERS:
		var hb: int = idx[hn]
		var dm := INF
		var tm := 0.0
		for i in n:
			var d := P[i].distance_to((poses[i][hb] as Transform3D).origin)
			if d < dm:
				dm = d
				tm = times[i]
		near[hn] = {"d_min_m": dm, "t": tm, "d_at_grab_m": P[gi].distance_to((poses[gi][hb] as Transform3D).origin)}
	# carry points (bulk 0): distance at the grab frame, the smallest over slow frames (the hand dwells:
	# a usable clip segment) and over all frames (may only pass through)
	var pel: int = idx["pelvis"]
	var spc: int = idx["spinec"]
	var belt := []
	for tp in targets.belt:
		belt.append([tp.az_deg] + _reach(poses, times, P, v, slow, gi, pel, tp.grip[0].pelvis))
	var chest := []
	for tp in targets.chest:
		chest.append([tp.y, tp.az_deg] + _reach(poses, times, P, v, slow, gi, spc, tp.grip[0].spinec))
	# downsampled path (10 Hz) as bind-equivalent positions (body frame), for plots / later tuning
	var trail := []
	var step := maxi(1, int(round(HZ / 10.0)))
	for i in range(0, n, step):
		trail.append([times[i], _bind_equiv(poses[i], P[i]), v[i]])
	return {"path_m": path, "grab_side_path_m": gs_path, "peak_speed_mps": vmax, "grab": grab, "arrival": arrival,
			"near_holsters": near, "prop_offset_at_grab_m": off[gi], "prop_offset_max_m": off_max,
			"prop_transfers": transfers.map(func(x): return {"kind": x.kind, "with": x.with, "t": x.t, "phase": x.phase, "prop_offset_parked_m": x.prop_offset_parked_m, "parked_drift_m": x.parked_drift_m, "parked_key_t": x.parked_key_t, "in_hand_key_t": x.key_t}),
			"barrel_start": _dir_words((poses[0][pb] as Transform3D).basis.orthonormalized() * Vector3(0, 0, 1)),
			"barrel_end": _dir_words((poses[n - 1][pb] as Transform3D).basis.orthonormalized() * Vector3(0, 0, 1)),
			"belt_reach": belt, "chest_reach": chest, "trail_bind_equiv": trail,
			"start_bind_equiv": _bind_equiv(poses[0], P[0]), "end_bind_equiv": _bind_equiv(poses[n - 1], P[n - 1])}


## [at_grab, slow_min, t_slow, any_min, t_any] for a carry point `loc` in bone b's rest space.
func _reach(poses: Array, times: PackedFloat64Array, P: PackedVector3Array, v: PackedFloat64Array, slow: float,
		gi: int, b: int, loc: Vector3) -> Array:
	var at_grab := P[gi].distance_to((poses[gi][b] as Transform3D) * loc)
	var smin := INF
	var ts := -1.0
	var amin := INF
	var ta := 0.0
	for i in P.size():
		var d := P[i].distance_to((poses[i][b] as Transform3D) * loc)
		if d < amin:
			amin = d
			ta = times[i]
		if v[i] <= slow and d < smin:
			smin = d
			ts = times[i]
	return [at_grab, smin, ts, amin, ta]


## A point carried back into the bind pose by one bone (rigidly).
func _in_bind(G: Dictionary, p: Vector3, b: int) -> Vector3:
	return rest_g[b] * ((G[b] as Transform3D).affine_inverse() * p)


## A point in the pose carried back into the bind pose by the nearest torso anchor (pelvis, spinea,
## spineb, spinec, spined; nearest origin in this pose): a body-frame position whatever the stance
## (the crouch flexes the spine about 40 deg over the pelvis, so a single anchor misplaces either the
## belt or the chest). Presentation only: stowed transforms are given in bone spaces (prop_in).
func _bind_equiv(G: Dictionary, p: Vector3) -> Vector3:
	var b := _anchor(G, p)
	return rest_g[b] * ((G[b] as Transform3D).affine_inverse() * p)


func _anchor(G: Dictionary, p: Vector3) -> int:
	var best := -1
	var bd := INF
	for n in ANCHORS:
		var b: int = idx[n]
		var d := (G[b] as Transform3D).origin.distance_to(p)
		if d < bd:
			bd = d
			best = b
	return best


## Handoff record at the grab frame: where on the body, and the stowed transform in each space.
func _handoff(G: Dictionary, h: String, grab: Dictionary) -> Dictionary:
	var pb: int = idx[PROP[h]]
	var prop: Transform3D = G[pb]
	var hand := ((G[idx[h + "_palm"]] as Transform3D) * rest[pb]).origin
	var q := _bind_equiv(G, hand)
	var qp := _bind_equiv(G, prop.origin)
	var az := rad_to_deg(atan2(q.x - _ring_c.x, q.z - _ring_c.y))
	var out := {"t": grab.t, "phase": grab.phase, "speed_mps": grab.speed_mps, "hold": grab.hold,
			"hand_skel": hand, "hand_bind_equiv": q, "prop_skel": prop.origin, "prop_bind_equiv": qp,
			"prop_to_hand_m": hand.distance_to(prop.origin), "wrist_skel": (G[idx[h + "_wrist"]] as Transform3D).origin,
			"region": _region(q, az), "belt_az_deg": az, "above_belt_mid_m": q.y - BELT_MID_Y,
			"outside_belt_ring_m": Vector2(q.x - _ring_c.x, q.z - _ring_c.y).length() - _ring_radius(az),
			"dist_m": {}, "prop_dist_m": {}}
	var best := ""
	var bd := INF
	for hn in HOLSTERS:
		var o := (G[idx[hn]] as Transform3D).origin
		var d := hand.distance_to(o)
		out.dist_m[hn] = d
		out.prop_dist_m[hn] = prop.origin.distance_to(o)
		if d < bd:
			bd = d
			best = hn
	out.nearest_holster = best
	var barrel := prop.basis.orthonormalized() * Vector3(0, 0, 1)
	out.barrel = {"skel": barrel, "words": _dir_words(barrel), "elev_deg": rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0)))}
	var up := prop.basis.orthonormalized() * Vector3(0, 1, 0)
	out.prop_up = {"skel": up, "words": _dir_words(up)}
	return out


## The prop where the clip parks it on the body the frame before an attach (after a detach): the
## source's own stowed transform of that object.
func _parked(G: Dictionary, h: String, t: float) -> Dictionary:
	var pb: int = idx[PROP[h]]
	var prop: Transform3D = G[pb]
	var q := _bind_equiv(G, prop.origin)
	var az := rad_to_deg(atan2(q.x - _ring_c.x, q.z - _ring_c.y))
	var out := {"t": t, "prop_skel": prop.origin, "prop_bind_equiv": q, "region": _region(q, az), "belt_az_deg": az,
			"above_belt_mid_m": q.y - BELT_MID_Y,
			"outside_belt_ring_m": Vector2(q.x - _ring_c.x, q.z - _ring_c.y).length() - _ring_radius(az),
			"prop_in": {}, "model_in": {}, "prop_dist_m": {}}
	for hn in HOLSTERS:
		out.prop_dist_m[hn] = prop.origin.distance_to((G[idx[hn]] as Transform3D).origin)
	for sn in SPACES:
		var S: Transform3D = G[idx[sn]]
		out.prop_in[sn] = _xf(S.affine_inverse() * prop)
		out.model_in[sn] = _xf(S.affine_inverse() * (prop * HALF_TURN))
	var barrel := prop.basis.orthonormalized() * Vector3(0, 0, 1)
	out.barrel = {"skel": barrel, "words": _dir_words(barrel), "elev_deg": rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0))),
			"bind_equiv": _bind_dir(G, prop.origin, barrel)}
	return out


## A direction at point p carried back into the bind pose like _bind_equiv (body-frame direction).
func _bind_dir(G: Dictionary, p: Vector3, d: Vector3) -> Vector3:
	var b := _anchor(G, p)
	return (rest_g[b].basis * ((G[b] as Transform3D).basis.inverse() * d)).normalized()


func _ring_radius(az: float) -> float:
	if _ring_r.is_empty():
		return 0.15
	var f := wrapf(az + 180.0, 0.0, 360.0) / BELT_STEP_DEG
	var i0 := int(floor(f)) % _ring_r.size()
	var i1 := (i0 + 1) % _ring_r.size()
	return lerpf(_ring_r[i0], _ring_r[i1], f - floor(f))


## Body region of a bind-equivalent point q (see _bind_equiv) with belt azimuth az (0 front, +90 left).
static func _region(q: Vector3, az: float) -> String:
	var side := "right" if q.x < -0.06 else ("left" if q.x > 0.06 else "centre")
	if q.y > 1.23:
		if q.z < -0.03:
			return "behind the neck" if side == "centre" else "over the %s shoulder (behind)" % side
		return "%s shoulder (front)" % side
	if q.y > 1.04:
		var up := q.y > 1.12
		if q.z < -0.09:
			return ("%s upper back" if up else "%s lower back") % side
		if q.z > 0.09:
			return ("%s chest" if up else "%s belly") % side
		return "%s flank" % side
	if q.y > 0.80:
		return _az_label(az) + " (belt level)"
	return "%s thigh" % side


static func _dir_words(d: Vector3) -> String:
	var parts := []
	if d.y > 0.35:
		parts.append("up")
	elif d.y < -0.35:
		parts.append("down")
	if d.z > 0.35:
		parts.append("forward")
	elif d.z < -0.35:
		parts.append("back")
	if d.x > 0.35:
		parts.append("left")
	elif d.x < -0.35:
		parts.append("right")
	return "-".join(parts) if not parts.is_empty() else "mixed"


static func _xf(t: Transform3D) -> Dictionary:
	var b := t.basis.orthonormalized()
	var q := b.get_rotation_quaternion()
	return {"origin": t.origin, "quat_xyzw": [q.x, q.y, q.z, q.w],
			"godot": "Transform3D(Basis(Quaternion(%.6f, %.6f, %.6f, %.6f)), Vector3(%.5f, %.5f, %.5f))" % [q.x, q.y, q.z, q.w, t.origin.x, t.origin.y, t.origin.z]}


## Full-tree check of the manual composition at phases 0, 0.5, 1.
func _validate(id: String, base: Dictionary, bp: Dictionary, partial: Clip, twin: Clip) -> void:
	var tree := _tree(base, partial, twin)
	for ph in [0.0, 0.5, 1.0]:
		var tp: float = ph * partial.length
		var tt: float = ph * twin.length if twin else 0.0
		tree.set("parameters/PS/seek_request", tp)
		if twin:
			tree.set("parameters/TS/seek_request", tt)
		tree.advance(0.0)
		var G := _pose(bp, partial, tp, twin, tt, false)
		for h in ["r", "l"]:
			var b: int = idx[PROP[h]]
			var d := sk.get_bone_global_pose(b).origin.distance_to((G[b] as Transform3D).origin)
			_val_n += 1
			if d > _val_worst:
				_val_worst = d
				_val_where = "%s phase %.1f %s" % [id, ph, h]
	_drop(tree)


# --- graph playback ---------------------------------------------------------------------------

func _graph_playback(ak: String, length: float, grab: Dictionary, timings: Dictionary) -> Dictionary:
	var a: Dictionary = graph.actions[ak]
	var w := ak.get_slice("/", 0)
	var key := ak.get_slice("/", 2)
	var cb: Variant = a.get("rate_callback")
	var expr: Array = cb.get("expr", []) if cb is Dictionary else []
	var reverse := float(a.get("start_phase", 0.0)) >= 0.5
	for e in expr:
		var s := String(e)
		if s.begins_with("IF !i32[D4+36] & !i32[D4+40]"):
			reverse = reverse and s.contains("* -")
	var eq: float = float((timings.get(w, {}) as Dictionary).get("equip_time", 0.45))
	var out := {"key": key, "state": a.get("state"), "state_offset": a.get("state_offset"),
			"twin_state": a.get("twin_state"), "start_phase": a.get("start_phase", 0.0),
			"rate_callback": cb.get("id") if cb is Dictionary else null, "rate_expr": expr,
			"reverse": reverse, "by_mode": a.get("by_mode"),
			"graph_rate": "clip rate x1 (unflagged branch: arg2 + from-ups(arg3)); x2 when D4+40 is set; negated when D4+36 is set (reverse flag)",
			"graph_duration_s": length, "frontier_equip_time_s": eq, "frontier_rate": length / maxf(eq, 1e-3)}
	var ph: float = grab.phase
	if reverse:
		out.handoff_after_s = {"graph": (1.0 - ph) * length, "frontier": (1.0 - ph) * eq,
				"what": "time from the holster start until the hand is at the stow point (reverse playback; ignores the 0.2 s OneShot fade-in)"}
	else:
		out.handoff_after_s = {"graph": ph * length, "frontier": ph * eq,
				"what": "time from the action start to the grab / release frame (forward playback)"}
	return out


func _graph_summary(cases: Dictionary) -> Dictionary:
	var out := {}
	for id in cases:
		if not String(id).begins_with("graph:"):
			continue
		var c: Dictionary = cases[id]
		var h: Dictionary = c.handoff[c.active_hand]
		out[String(id).substr(6)] = {"clip": c.clip, "twin": c.twin, "active_hand": c.active_hand,
				"grab_phase": h.phase, "region": h.region, "nearest_holster": h.nearest_holster,
				"dist_to_nearest_m": (h.dist_m as Dictionary)[h.nearest_holster], "reverse": c.graph.reverse,
				"barrel": h.barrel.words, "handoff_after_s": c.graph.handoff_after_s}
	return out


## Graph sequences: grab end -> draw start (the hand should already be at the stow point), and the
## reversed draw's end (clip start) -> holster_finish start.
func _sequences(cases: Dictionary) -> Dictionary:
	var out := {}
	for w in ["bow", "musket", "pistol"]:
		for st in ["stand", "crouch"]:
			var grab_id := "graph:%s/%s/grab" % [w, st]
			var eq_id := "graph:%s/%s/equip" % [w, st]
			var fin_id := "graph:%s/%s/holster_finish" % [w, st]
			if not (cases.has(grab_id) and cases.has(eq_id) and cases.has(fin_id)):
				continue
			var e := _endpoints(cases[eq_id])
			var g := _endpoints(cases[grab_id])
			var f := _endpoints(cases[fin_id])
			out["%s/%s" % [w, st]] = {
				"grab_end_to_draw_start_m": {"r": g.end.r.distance_to(e.start.r), "l": g.end.l.distance_to(e.start.l)},
				"draw_start_to_finish_start_m": {"r": e.start.r.distance_to(f.start.r), "l": e.start.l.distance_to(f.start.l)},
				"draw_end_to_finish_end_m": {"r": e.end.r.distance_to(f.end.r), "l": e.end.l.distance_to(f.end.l)},
				"what": "hand-point positions (bind-equivalent body frame); grab (idle^grab) should end where the draw (grab^idle) starts; holster = draw reversed, then holster_finish from the same point back to idle",
			}
	return out


static func _endpoints(c: Dictionary) -> Dictionary:
	return {"start": {"r": c.hands.r.start_bind_equiv, "l": c.hands.l.start_bind_equiv},
			"end": {"r": c.hands.r.end_bind_equiv, "l": c.hands.l.end_bind_equiv}}


# --- reach tables -------------------------------------------------------------------------------

func _verdict(d: float) -> String:
	if d <= REACH_DIRECT:
		return "direct"
	if d <= REACH_CLOSE:
		return "close"
	if d <= REACH_APPROX:
		return "approximation"
	return "no"


## Usable reach of one case / hand to a carry point: the grab frame or a slow dwell (a clip segment).
## e = [at_grab, slow_min, t_slow, any_min, t_any].
func _usable(c: Dictionary, h: String, e: Array) -> Dictionary:
	var at_grab: float = e[0]
	var smin: float = e[1]
	var use_grab := at_grab <= smin
	var t: float = c.hands[h].grab.t if use_grab else e[2]
	return {"err_m": minf(at_grab, smin), "how": "grab frame" if use_grab else "segment (slow dwell)", "t": t,
			"phase": t / maxf(float(c.length_s), 1e-6), "err_at_grab_m": at_grab, "err_slow_min_m": smin,
			"err_pass_min_m": e[3], "t_pass": e[4]}


## Per belt azimuth: the best cases for each hand (grab frame or slow dwell), over every measured clip.
func _belt_reach_table(cases: Dictionary, targets: Dictionary) -> Array:
	var out := []
	for j in targets.belt.size():
		var az: float = targets.belt[j].az_deg
		var ranked := []
		for id in cases:
			var c: Dictionary = cases[id]
			for h in ["r", "l"]:
				var e: Array = (c.hands[h].belt_reach[j] as Array).slice(1)
				var u := _usable(c, h, e)
				u.case = id
				u.hand = h
				u.mirrored = c.mirrored
				ranked.append(u)
		ranked.sort_custom(func(a, b): return a.err_m < b.err_m)
		var best_r := ranked.filter(func(x): return x.hand == "r")
		var best_l := ranked.filter(func(x): return x.hand == "l")
		out.append({"az_deg": az, "side": targets.belt[j].side, "grip_point_skel": targets.belt[j].grip[0].skel,
				"best_right_hand": best_r.slice(0, 3), "best_left_hand": best_l.slice(0, 3),
				"best_right_unmirrored": best_r.filter(func(x): return not x.mirrored).slice(0, 1),
				"best_left_unmirrored": best_l.filter(func(x): return not x.mirrored).slice(0, 1),
				"verdict_right": _verdict(best_r[0].err_m) if not best_r.is_empty() else "no",
				"verdict_left": _verdict(best_l[0].err_m) if not best_l.is_empty() else "no"})
	return out


## Candidate carry points for a second (third, ...) pistol and how close each source clip gets.
func _multi_pistol(cases: Dictionary, targets: Dictionary) -> Dictionary:
	var named := {
		"right_hip": {"kind": "belt", "az": -90.0, "hand": "r", "how": "first pistol, belt at the right hip (the source pistol draw)"},
		"right_front": {"kind": "belt", "az": -45.0, "hand": "r", "how": "belt / sash front-right, butt back (right-hand draw)"},
		"front": {"kind": "belt", "az": 0.0, "hand": "r", "how": "sash front centre, butt to the right"},
		"left_front_cross": {"kind": "belt", "az": 45.0, "hand": "r", "how": "left front, butt forward: right-hand cross-draw"},
		"left_hip_cross": {"kind": "belt", "az": 90.0, "hand": "r", "how": "left hip, butt forward: right-hand cross-draw"},
		"left_hip_same_side": {"kind": "belt", "az": 90.0, "hand": "l", "how": "left hip, butt back: left-hand draw (then pass to the right hand or fire left)"},
		"left_front_same_side": {"kind": "belt", "az": 45.0, "hand": "l", "how": "left front, butt back: left-hand draw"},
		"back_right": {"kind": "belt", "az": -135.0, "hand": "r", "how": "behind the right hip (right-hand draw)"},
		"back_left_same_side": {"kind": "belt", "az": 135.0, "hand": "l", "how": "behind the left hip (left-hand draw)"},
		"chest_left_same_side": {"kind": "chest", "y": 1.15, "az": 45.0, "hand": "l", "how": "sling / strap on the left breast, left-hand draw"},
		"chest_right_same_side": {"kind": "chest", "y": 1.15, "az": -45.0, "hand": "r", "how": "sling / strap on the right breast, right-hand draw"},
		"small_of_back": {"kind": "belt", "az": 180.0, "hand": "r", "how": "small of the back"},
		"chest_left_cross": {"kind": "chest", "y": 1.15, "az": 30.0, "hand": "r", "how": "pistol sling / baldric, left chest, butt to the right: right-hand cross-draw"},
		"chest_centre": {"kind": "chest", "y": 1.15, "az": 0.0, "hand": "r", "how": "pistol sling at the breast bone"},
		"chest_right": {"kind": "chest", "y": 1.15, "az": -30.0, "hand": "r", "how": "right chest"},
		"chest_left_low_cross": {"kind": "chest", "y": 1.05, "az": 30.0, "hand": "r", "how": "sling hanging lower, left ribs"},
		"chest_left_high_cross": {"kind": "chest", "y": 1.25, "az": 30.0, "hand": "r", "how": "sling high on the left breast"},
	}
	var out := {"targets": {}, "note": "err = distance between the hand point (palm + the prop bone's rest offset: where a held grip sits) and the carry point's grip point, at the clip's grab frame or, if smaller, the closest frame where the hand is slow (a clip segment that could be played to there and back); err_pass_min_m = closest pass at any speed (not usable on its own). M: = mirrored clip (needs a mirrored copy of the clip at build time). Verdicts: direct <= %.2f m, close <= %.2f, approximation <= %.2f, else no" % [REACH_DIRECT, REACH_CLOSE, REACH_APPROX]}
	for key in named:
		var spec: Dictionary = named[key]
		var j := -1
		if spec.kind == "belt":
			for i in targets.belt.size():
				if is_equal_approx(float(targets.belt[i].az_deg), float(spec.az)):
					j = i
		else:
			for i in targets.chest.size():
				if is_equal_approx(float(targets.chest[i].az_deg), float(spec.az)) and is_equal_approx(float(targets.chest[i].y), float(spec.y)):
					j = i
		if j < 0:
			continue
		var ranked := []
		for id in cases:
			var c: Dictionary = cases[id]
			var hr: Dictionary = c.hands[spec.hand]
			var e: Array = (hr.belt_reach[j] as Array).slice(1) if spec.kind == "belt" else (hr.chest_reach[j] as Array).slice(2)
			var u := _usable(c, spec.hand, e)
			u.case = id
			u.mirrored = c.mirrored
			u.family = c.family
			ranked.append(u)
		ranked.sort_custom(func(a, b): return a.err_m < b.err_m)
		var top := ranked.slice(0, 5)
		var tg: Dictionary = targets.belt[j] if spec.kind == "belt" else targets.chest[j]
		out.targets[key] = {"how": spec.how, "hand": spec.hand, "kind": spec.kind, "az_deg": spec.az,
				"grip_point_skel": tg.grip[0].skel, "best": top,
				"verdict": _verdict(top[0].err_m) if not top.is_empty() else "no",
				"best_unmirrored": ranked.filter(func(x): return not x.mirrored).slice(0, 3)}
	return out


## Throwables: belt draws (tomahawk, atlatl), back draws (spear pair, dart bundle), quiver reach.
func _throwable_summary(cases: Dictionary, targets: Dictionary) -> Dictionary:
	var pick := func(id: String) -> Variant:
		if not cases.has(id):
			return null
		var c: Dictionary = cases[id]
		var h: Dictionary = c.handoff[c.active_hand]
		return {"case": id, "clip": c.clip, "hand": c.active_hand, "length_s": c.length_s, "grab_t": h.t, "grab_phase": h.phase,
				"rule": c.hands[c.active_hand].grab.rule, "region": h.region, "hand_bind_equiv": h.hand_bind_equiv,
				"belt_az_deg": h.belt_az_deg, "above_belt_mid_m": h.above_belt_mid_m, "outside_belt_ring_m": h.outside_belt_ring_m,
				"nearest_holster": h.nearest_holster, "dist_m": h.dist_m, "barrel": h.barrel.words,
				"prop_in_hand": float(h.prop_to_hand_m) <= PROP_OFF}
	var out := {"what": "source clips that serve a throwable draw: from the belt (tomahawk, atlatl), from the back (spear pair, dart bundle) and the quiver reach; each entry is the clip's grab frame (hand region, belt coordinates, the weapon-hand prop's barrel)"}
	for st in ["stand", "crouch"]:
		out[st] = {
			"belt_right_hip": [pick.call("clip:actor_b-p-stealth-draw-p^idle--arm-r--no-pack@" + st), pick.call("clip:actor_b-p-stealth-idle^p-grab--arm-r--no-pack@" + st)],
			"belt_back_right": [pick.call("clip:actor_b-p-stealth-draw-p^idle--arm-r@" + st), pick.call("clip:actor_b-pistol-pack-unholster--part@" + st)],
			"belt_small_of_back": [pick.call("clip:actor_b-p-molotov-draw^idle--part@" + st), pick.call("clip:actor_b-p-molotov-idle^draw--part@" + st)],
			"belt_left_side_mirrored": [pick.call("M:clip:actor_b-p-stealth-draw-p^idle--arm-r--no-pack@" + st), pick.call("M:clip:actor_b-p-molotov-draw^idle--part@" + st)],
			"back_over_left_shoulder": [pick.call("clip:actor_b-lg-stealth-draw^idle--arm-r@" + st), pick.call("clip:actor_b-lg-stealth-idle^grab--arm-r@" + st)],
			"back_over_right_shoulder_mirrored": [pick.call("M:clip:actor_b-lg-stealth-draw^idle--arm-r@" + st)],
			"back_left_shoulder_blade": [pick.call("clip:actor_b-p-bow-draw-grab^idle--part@" + st), pick.call("clip:actor_b-p-bow-draw-idle^grab--part@" + st)],
			"quiver_reach": [pick.call("clip:actor_b-p-bow-reload--part@" + st), pick.call("clip:actor_b-p-crouch-bow-reload--part@" + st)],
		}
	return out


## Source stow points: where the source clips put / take each object, with the stowed transform of
## the weapon hand's prop (the Frontier socket bone): "parked" = the prop where the clip parks it on
## the body (the key before the attach / after the release; the source's own stowed pose), "in_hand"
## = the prop in the hand at the grab frame (seamless for Frontier's reversed-draw holster), and the
## jump between them. Mirrored entries need a mirrored clip.
const STOW_POINTS := [
	["pistol_right_hip", "r", "backpack-off pistol set (the source's no-backpack holster): grab parks the pistol here, draw starts here",
		["clip:actor_b-p-stealth-idle^p-grab--arm-r--no-pack@%s", "clip:actor_b-p-stealth-draw-p^idle--arm-r--no-pack@%s", "clip:actor_b-p-stealth-stow-p^idle--arm-r--no-pack@%s"]],
	["pistol_back_right", "r", "default (backpack-on) pistol set = graph pistol grab / equip / holster: behind the right hip, above the belt",
		["graph:pistol/%s/grab", "graph:pistol/%s/equip", "clip:actor_b-p-stealth-stow-p^idle--arm-r@%s"]],
	["pistol_left_hip_mirrored", "l", "MIRRORED backpack-off pistol set (left hand, left hip)",
		["M:clip:actor_b-p-stealth-idle^p-grab--arm-r--no-pack@%s", "M:clip:actor_b-p-stealth-draw-p^idle--arm-r--no-pack@%s", "M:clip:actor_b-p-stealth-stow-p^idle--arm-r--no-pack@%s"]],
	["pistol_back_left_mirrored", "l", "MIRRORED default pistol set (left hand, behind the left hip)",
		["M:clip:actor_b-p-crouch-idle^p-grab--arm-r@%s", "M:clip:actor_b-p-stealth-draw-p^idle--arm-r@%s", "M:clip:actor_b-p-stealth-stow-p^idle--arm-r@%s"]],
	["pistol_small_of_back", "r", "pistol-pack unholster / holster (right hand behind the back)",
		["clip:actor_b-pistol-pack-unholster--part@%s", "clip:actor_b-pistol-pack-holster--part@%s"]],
	["object_small_of_back", "r", "graph molotov-pack-draw (one-hand throwable drawn from behind the belt, right hand)",
		["clip:actor_b-p-molotov-draw^idle--part@%s", "clip:actor_b-p-molotov-idle^draw--part@%s"]],
	["long_gun_left_shoulder", "r", "graph musket grab / equip / holster_finish: left hand behind the left shoulder / neck (both props on the weapon; Frontier hangs the musket on the right prop)",
		["graph:musket/%s/grab", "graph:musket/%s/equip", "graph:musket/%s/holster_finish"]],
	["long_gun_right_shoulder_mirrored", "l", "MIRRORED long-gun draw (right hand over the right shoulder)",
		["M:clip:actor_b-lg-stealth-draw^idle--arm-r@%s"]],
	["bow_left_back", "l", "graph bow grab / equip / crouch holster_finish: left hand at the left shoulder blade",
		["graph:bow/%s/grab", "graph:bow/%s/equip", "clip:actor_b-p-bow-stow-grab^idle--part@%s"]],
	["quiver_right_shoulder", "r", "graph bow nock (p-bow-reload): the clip starts with the right hand at the quiver behind the right shoulder (the arrow prop is parked away from the hand then: use the hand point)",
		["clip:actor_b-p-bow-reload--part@stand", "clip:actor_b-p-crouch-bow-reload--part@crouch"]],
	["strap_left_chest", "l", "flashlight draw / holster: left hand at the left breast strap",
		["clip:actor_b-fist-ambi-flashlight-draw--part@%s", "clip:actor_b-fist-ambi-flashlight-holster-part@%s"]],
	["strap_right_chest_mirrored", "r", "MIRRORED flashlight draw (right hand, right breast)",
		["M:clip:actor_b-fist-ambi-flashlight-draw--part@%s"]],
]


func _stow_points(cases: Dictionary) -> Dictionary:
	var out := {"what": "per stow point and stance: the source case(s), the grabbing hand's region and belt coordinates, and the weapon-hand prop's parked / in-hand transforms (prop_in / model_in per space; model = prop * half turn)", "points": {}}
	for e in STOW_POINTS:
		var name: String = e[0]
		var wh: String = e[1]
		var entry := {"weapon_hand": wh, "source": e[2], "stances": {}}
		for st in ["stand", "crouch"]:
			var recs := []
			for pat in e[3]:
				var id: String = pat % st if pat.contains("%s") else pat
				if not pat.contains("%s") and not id.ends_with("@" + st):
					continue
				if not cases.has(id):
					continue
				var c: Dictionary = cases[id]
				var act: String = c.active_hand
				var h: Dictionary = c.handoff[act]
				var r := {"case": id, "grab_hand": act, "grab_t": h.t, "grab_phase": h.phase, "rule": c.hands[act].grab.rule,
						"prop_to_hand_m": h.prop_to_hand_m, "prop_in_hand": float(h.prop_to_hand_m) <= PROP_OFF,
						"hand_region": h.region, "hand_bind_equiv": h.hand_bind_equiv, "belt_az_deg": h.belt_az_deg,
						"above_belt_mid_m": h.above_belt_mid_m, "outside_belt_ring_m": h.outside_belt_ring_m,
						"in_hand": c.props_at_grab[wh]}
				if c.has("props_parked"):
					r.parked = c.props_parked[wh]
					r.jump_parked_to_in_hand = c.props_parked.jump_to_grab[wh]
				recs.append(r)
			if not recs.is_empty():
				entry.stances[st] = recs
		# one stowed transform for both stances? the weapon prop (parked, else in hand) of the first
		# record of each stance, compared in every carrying space
		if entry.stances.has("stand") and entry.stances.has("crouch"):
			var a: Dictionary = entry.stances.stand[0]
			var b: Dictionary = entry.stances.crouch[0]
			var pa: Dictionary = a.get("parked", a.in_hand)
			var pb: Dictionary = b.get("parked", b.in_hand)
			var cons := {}
			for sn in SPACES:
				var oa: Vector3 = pa.prop_in[sn].origin
				var ob: Vector3 = pb.prop_in[sn].origin
				var qa := Quaternion(pa.prop_in[sn].quat_xyzw[0], pa.prop_in[sn].quat_xyzw[1], pa.prop_in[sn].quat_xyzw[2], pa.prop_in[sn].quat_xyzw[3])
				var qb := Quaternion(pb.prop_in[sn].quat_xyzw[0], pb.prop_in[sn].quat_xyzw[1], pb.prop_in[sn].quat_xyzw[2], pb.prop_in[sn].quat_xyzw[3])
				cons[sn] = {"pos_m": oa.distance_to(ob), "rot_deg": rad_to_deg(qa.angle_to(qb))}
			entry.stand_vs_crouch = {"what": "difference of the stowed weapon prop between the stand and crouch source frames, per carrying space (small = one stowed transform in that space serves both stances)", "spaces": cons}
		out.points[name] = entry
	return out


## Which bone should carry a stowed item: a point rigidly carried by each candidate parent (placed at
## the same bind-pose position) drifts apart from the reference parent's copy over locomotion clips.
## Reference: pelvis for belt points (the belt is skinned to the band centre of the coat, which follows
## the pelvis / lower spine), spinec for back points. Full-body clips played alone, 30 Hz.
func _parent_drift(targets: Dictionary) -> Dictionary:
	var pts := {}
	for e in targets.belt:
		if is_equal_approx(float(e.az_deg), -90.0):
			pts["belt_right_hip"] = {"p": e.grip[0].skel, "ref": "pelvis", "parents": ["pelvis", "holster_pistol", "holster_melee", "root", "spinea"]}
		if is_equal_approx(float(e.az_deg), -135.0):
			pts["belt_back_right"] = {"p": e.grip[0].skel, "ref": "pelvis", "parents": ["pelvis", "holster_pistol", "root", "spinea"]}
		if is_equal_approx(float(e.az_deg), 90.0):
			pts["belt_left_hip"] = {"p": e.grip[0].skel, "ref": "pelvis", "parents": ["pelvis", "holster_melee", "root", "spinea"]}
	pts["back_mid"] = {"p": rest_g[idx["holster_long"]].origin, "ref": "spinec", "parents": ["spinec", "spineb", "spined", "holster_long", "pelvis"]}
	pts["back_shoulders"] = {"p": Vector3(0.0, 1.30, -0.16), "ref": "spinec", "parents": ["spinec", "spineb", "spined", "holster_long"]}
	var rest_pose := {"p": rest_p, "q": rest_q, "s": rest_s}
	var out := {"clips": DRIFT_CLIPS, "points": {}, "what": "max / mean distance (m) between a point carried by each parent and the same point carried by the reference parent, over the clips (30 Hz)"}
	for pk in pts:
		var spec: Dictionary = pts[pk]
		var rows := {}
		for par in spec.parents:
			rows[par] = {"max_m": 0.0, "mean_m": 0.0, "worst_clip": "", "n": 0}
		for cn in DRIFT_CLIPS:
			var c := _clip(cn)
			if c == null:
				continue
			var n := maxi(2, int(ceil(c.length * 30.0)) + 1)
			for i in n:
				var t := minf(i / 30.0, c.length)
				var G := _pose(rest_pose, c, t, null, 0.0, false)
				var pr: Transform3D = G[idx[spec.ref]]
				var ref_p: Vector3 = pr * (rest_g[idx[spec.ref]].affine_inverse() * (spec.p as Vector3))
				for par in spec.parents:
					var gp: Transform3D = G[idx[par]]
					var d := (gp * (rest_g[idx[par]].affine_inverse() * (spec.p as Vector3))).distance_to(ref_p)
					var r: Dictionary = rows[par]
					if d > float(r.max_m):
						r.max_m = d
						r.worst_clip = "%s t %.2f" % [cn, t]
					r.mean_m = float(r.mean_m) + d
					r.n = int(r.n) + 1
		for par in rows:
			var r: Dictionary = rows[par]
			r.mean_m = float(r.mean_m) / maxf(float(r.n), 1.0)
			r.erase("n")
		out.points[pk] = {"point_bind": spec.p, "reference": spec.ref, "parents": rows}
	return out


func _unarmed_summary() -> Dictionary:
	if not FileAccess.file_exists(GRAPH_SEL):
		warnings.append("unarmed: %s missing (python3 tools/loadout/resolve_loadout_graph.py)" % GRAPH_SEL)
		return {"missing": GRAPH_SEL, "how": "python3 tools/loadout/resolve_loadout_graph.py"}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(GRAPH_SEL))
	if not d is Dictionary:
		return {"unreadable": GRAPH_SEL}
	var bo: Dictionary = d.get("backpack_off", {})
	var pistol := {}
	for k in (bo.get("actions", {}) as Dictionary):
		if String(k).begins_with("pistol/"):
			pistol[k] = {"backpack_on": bo.actions[k].backpack_on.get("partial"), "backpack_off": bo.actions[k].backpack_off.get("partial")}
	return {"source": GRAPH_SEL, "profile": d.get("profile"), "set_remap_counts": d.get("set_remap_counts"),
			"key_roles": d.get("key_roles"), "hand_states": {
				"stand": {"idle_hands": d.hand_states.stand.idle_hands.clip, "weapon_out": d.hand_states.stand.weapon_out.clip},
				"crouch": {"idle_hands": d.hand_states.crouch.idle_hands.clip, "weapon_out": d.hand_states.crouch.weapon_out.clip}},
			"actions": (d.get("actions", {}) as Dictionary).keys().map(func(k): return [k, (d.actions[k].leaves as Array).map(func(l): return l.clip)]),
			"backpack_off": {"set": bo.get("set"), "records": bo.get("set_remaps"), "changed_actions": bo.get("changed"), "pistol": pistol}}


func _rest_info() -> Dictionary:
	var out := {}
	for n in HOLSTERS + ["pelvis", "spinec", "spined", "root", "r_hand_prop_attachment", "l_hand_prop_attachment"]:
		var b: int = idx[n]
		out[n] = {"parent": names[parent[b]] if parent[b] >= 0 else null, "rest_local": _xf(rest[b]),
				"rest_skel": _xf(rest_g[b]),
				"rest_pelvis_rel": rest_g[b].origin - rest_g[idx["pelvis"]].origin}
	return out


# --- output -------------------------------------------------------------------------------------

static func _round(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if is_inf(v) or is_nan(v):
				return null
			return snappedf(v, 0.00001)
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.00001), snappedf(v.y, 0.00001), snappedf(v.z, 0.00001)]
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[str(k)] = _round(v[k])
			return d
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(_round(x))
			return a
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a := []
			for x in v:
				a.append(snappedf(x, 0.00001))
			return a
		TYPE_PACKED_STRING_ARRAY:
			return Array(v)
		TYPE_STRING_NAME:
			return String(v)
	return v
