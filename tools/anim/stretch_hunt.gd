extends SceneTree
## Stretch hunt (the owner, 2026-10-11: "sometime the body like glitches it turns elastic why is this"): real % ring matches,
## headless, the player played by the film's expert input model (tools/ring/highlight_input.gd) against a real bot, fire's
## player wearing the Lightning Pistol (as the owner's save has it). Every drawn frame, in each fighter skeleton's own
## skeleton_updated (the final pose, after every modifier: read anywhere else the bones are the tree's pose), it looks for
## what makes a skinned body stretch:
##   ORDER    an active modifier after the body (CharacterBodyMesh): its helpers (the shoulder and forearm twist, the armpit,
##            the skirt) were made from the pose before that modifier moved the bones, and the skin stretches between them
##   LENGTH   a bone whose distance to its parent is off its rest length by more than LEN_M (a bone pulled away: a stretched limb)
##   SCALE    a bone whose global scale is off its rest's by more than SCALE_K
##   TWIST    a forearm or shin twisted past TWIST_DEG about its own axis against the bone above (the candy-wrapper squeeze)
##   SNAP     a skin twist bone (the forearm's and the upper arm's) turned more than SNAP_DEG about its limb in one frame
##            against the bone it hangs off: the skin wrung round at once (the "elastic" glitch)
## Each finding is told once a second at most per kind and bone, with what was playing (the cast's clip and phase, the
## lower body, the ring state, the knock; a bot's clip).
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/anim/stretch_hunt.gd -- [elements=fire,earth,water,air]
##       [seconds=60] [seed=5100] [continuity=0]   (0: CharacterBodyMesh's twist bones as before their continuity, to compare)
##       [cap=0]   (0: the twist bones turn any amount in a frame, as before CharacterBodyMesh.TWIST_STEP_MAX)
## Lines: STRETCH {json}, STRETCH_SUMMARY {json}, STRETCH HUNT DONE.

const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const InputPlayer := preload("res://tools/ring/highlight_input.gd")
const OWN_CFG := "user://stretch_hunt.cfg"
const FOES := {"earth": "water", "water": "fire", "fire": "air", "air": "earth"}
const FPS := 60.0
const LEN_M := 0.02
const SCALE_K := 0.02
const TWIST_DEG := 150.0
const TWISTS := [["r_elbow", "r_wrist"], ["l_elbow", "l_wrist"], ["r_knee", "r_ankle"], ["l_knee", "l_ankle"]]
const PISTOL := "fire.lightning.pistol"
## The skin's twist bones and the bone each hangs off (CharacterBodyMesh: 30/60/90 % of the wrist's roll; 1/3, 2/3 of the
## upper arm's twist), and the one-frame turn about the limb that counts as a snap.
## [helper, the bone it is measured against, the limb's line from, to]
const SNAPS := [["r_forarm_twist_a", "r_elbow", "r_elbow", "r_wrist"], ["r_forarm_twist_b", "r_elbow", "r_elbow", "r_wrist"],
		["r_forarm_twist_c", "r_elbow", "r_elbow", "r_wrist"], ["l_forarm_twist_a", "l_elbow", "l_elbow", "l_wrist"],
		["l_forarm_twist_b", "l_elbow", "l_elbow", "l_wrist"], ["l_forarm_twist_c", "l_elbow", "l_elbow", "l_wrist"],
		["r_shoulder_twist_c", "r_shoulder", "r_shoulder", "r_elbow"], ["r_shoulder_twist_d", "r_shoulder", "r_shoulder", "r_elbow"],
		["l_shoulder_twist_c", "l_shoulder", "l_shoulder", "l_elbow"], ["l_shoulder_twist_d", "l_shoulder", "l_shoulder", "l_elbow"]]
const SNAP_DEG := 60.0
var _snap_last := {}       ## skeleton instance id -> {bone: last relation}

var elements: Array = ["fire", "earth", "water", "air"]
var seconds := 60.0
var seed_n := 5100
var level: RingLevel
var mode: RingMode
var player: FrontierPlayer
var sim: Node
var el_now := ""
var findings: Array = []
var _seen := {}            ## "kind|who|bone" -> last time told (s)
var _hooked := {}          ## skeleton instance id -> true
var _rest_len := {}        ## skeleton instance id -> {bone: rest length}
var _counts := {}          ## "kind|who|bone|ctx" -> n frames
var _frames := 0


func _initialize() -> void:
	var a := CaptureKit.args({"elements": ",".join(elements), "seconds": str(seconds), "seed": str(seed_n), "continuity": "1",
			"cap": "1"})
	CharacterBodyMesh.twist_continuity = String(a.continuity) != "0"
	CharacterBodyMesh.twist_step_cap = String(a.cap) != "0"
	elements = Array(String(a.elements).split(",", false))
	seconds = float(a.seconds)
	seed_n = int(a.seed)
	create_timer(seconds * elements.size() + 300.0, true, false, true).timeout.connect(func() -> void:
		print("STRETCH HUNT FAILED (watchdog)")
		quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = OWN_CFG
	InputSetup.ensure()
	RingReplay.force = "off"
	MatchSetup.incoming = true
	MatchSetup.format = "1v1"
	MatchSetup.element = String(elements[0])
	MatchSetup.foes = [String(FOES.get(String(elements[0]), "water"))]
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 1800:
		await physics_frame
		level = current_scene as RingLevel
		mode = RingMode.find(self)
		if level != null and mode != null and mode.foe != null and mode.phase == "FIGHT":
			break
	if mode == null or mode.foe == null:
		print("STRETCH HUNT FAILED: no match")
		return _quit(1)
	player = level.player
	player.ignore_mouse_capture = true
	player.controls = PlayerControls.new(false)
	for i in elements.size():
		var el := String(elements[i])
		if i > 0:
			MatchSetup.element = el
			MatchSetup.foes = [String(FOES.get(el, "water"))]
			mode.restart()
			while mode.phase != "FIGHT":
				await physics_frame
		await _hunt(el, seed_n + i * 17)
	_summary()
	print("STRETCH HUNT DONE")
	_quit(0)


func _wear() -> void:
	if el_now == "fire":
		BendLoadout.wear(player, [PISTOL], "", "fire")
	else:
		BendLoadout.clear(player)


func _hunt(el: String, sd: int) -> void:
	el_now = el
	_wear()
	if is_instance_valid(sim):
		sim._let_go()
		sim.free()
	sim = InputPlayer.new()
	sim.setup(player, mode, "expert", sd)
	level.add_child(sim)
	var n := int(seconds * FPS)
	var done := 0
	while done < n:
		await process_frame
		if mode.phase != "FIGHT":
			if mode.phase in ["DONE", "END", "RESULT"]:
				mode.restart()
				while mode.phase != "FIGHT":
					await physics_frame
				_wear()
			continue
		done += 1
		_frames += 1
		for f: Node3D in _fighters():
			_hook(f)


func _fighters() -> Array:
	var outl: Array = [player]
	for b in mode.bots():
		if b != null and is_instance_valid(b):
			outl.append(b)
	return outl


func _skeleton(f: Node3D) -> Skeleton3D:
	if f == player:
		return player.skeleton
	var body: Variant = f.get(&"body")
	if body is NpcBody and (body as NpcBody).sk != null:
		return (body as NpcBody).sk
	var ks := f.find_children("*", "Skeleton3D", true, false)
	return ks[0] as Skeleton3D if not ks.is_empty() else null


## The fighter's skeleton watched in its own update (once).
func _hook(f: Node3D) -> void:
	var sk := _skeleton(f)
	if sk == null or not is_instance_valid(sk):
		return
	var id := sk.get_instance_id()
	if _hooked.has(id):
		return
	_hooked[id] = true
	var rl := {}
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		if p < 0:
			continue
		rl[b] = sk.get_bone_global_rest(b).origin.distance_to(sk.get_bone_global_rest(p).origin)
	_rest_len[id] = rl
	sk.skeleton_updated.connect(_check.bind(f, sk))


func _check(f: Node3D, sk: Skeleton3D) -> void:
	if not is_instance_valid(f) or not is_instance_valid(sk) or mode == null or mode.phase != "FIGHT" or not sk.is_visible_in_tree():
		return
	var who := "player" if f == player else "bot"
	var ctx := _context(f)
	# ORDER: an active modifier after the body
	var body_i := -1
	for i in sk.get_child_count():
		if sk.get_child(i) is CharacterBodyMesh:
			body_i = i
	if body_i >= 0:
		for i in range(body_i + 1, sk.get_child_count()):
			var c := sk.get_child(i)
			if c is SkeletonModifier3D and (c as SkeletonModifier3D).active and (c as SkeletonModifier3D).influence > 0.0:
				_tell("ORDER", who, "%s (%s)" % [c.name, c.get_class()], 1.0, ctx)
	# LENGTH and SCALE
	var rl: Dictionary = _rest_len.get(sk.get_instance_id(), {})
	for b: int in rl:
		var n := sk.get_bone_name(b)
		if n == "root" or n == "pelvis" or n.contains("prop") or n.contains("offset") or n.contains("_grp"):
			continue
		var g := sk.get_bone_global_pose(b)
		var pg := sk.get_bone_global_pose(sk.get_bone_parent(b))
		var d := absf(g.origin.distance_to(pg.origin) - float(rl[b]))
		if d > LEN_M:
			_tell("LENGTH", who, n, d, ctx)
		var sc := g.basis.get_scale()
		var rs := sk.get_bone_global_rest(b).basis.get_scale()
		var ds := maxf(maxf(absf(sc.x / rs.x - 1.0), absf(sc.y / rs.y - 1.0)), absf(sc.z / rs.z - 1.0))
		if ds > SCALE_K:
			_tell("SCALE", who, n, ds, ctx)
	# SNAP: a skin twist bone (CharacterBodyMesh's forearm and upper-arm helpers) turned about its limb more than SNAP_DEG
	# against the bone it hangs off since the last frame: the skin wrung round in one frame (the rubber snap)
	var sid := sk.get_instance_id()
	var last: Dictionary = _snap_last.get(sid, {})
	for pair: Array in SNAPS:
		var hb := sk.find_bone(String(pair[0]))
		var rb := sk.find_bone(String(pair[1]))
		if hb < 0 or rb < 0:
			continue
		var relq := (sk.get_bone_global_pose(rb).basis.orthonormalized().inverse() * sk.get_bone_global_pose(hb).basis.orthonormalized()).get_rotation_quaternion()
		if last.has(hb):
			var dq := (last[hb] as Quaternion).inverse() * relq
			var la := sk.find_bone(String(pair[2]))
			var lb := sk.find_bone(String(pair[3]))
			var ax := (sk.get_bone_global_rest(hb).basis.orthonormalized().inverse() * (sk.get_bone_global_rest(lb).origin - sk.get_bone_global_rest(la).origin)).normalized()
			var pr := Vector3(dq.x, dq.y, dq.z).dot(ax)
			var tw := Quaternion(ax.x * pr, ax.y * pr, ax.z * pr, dq.w).normalized()
			var deg := rad_to_deg(2.0 * acos(clampf(absf(tw.w), 0.0, 1.0)))
			if deg > SNAP_DEG:
				_tell("SNAP", who, String(pair[0]), deg, ctx)
		last[hb] = relq
	_snap_last[sid] = last
	# TWIST: the lower bone's turn about its own axis against the upper's, from their rest relation
	for pair: Array in TWISTS:
		var u := sk.find_bone(String(pair[0]))
		var l := sk.find_bone(String(pair[1]))
		if u < 0 or l < 0:
			continue
		var rel := sk.get_bone_global_pose(u).basis.orthonormalized().inverse() * sk.get_bone_global_pose(l).basis.orthonormalized()
		var rrel := sk.get_bone_global_rest(u).basis.orthonormalized().inverse() * sk.get_bone_global_rest(l).basis.orthonormalized()
		var q := (rrel.inverse() * rel).get_rotation_quaternion()
		# (the lower bone's own axis in its frame: toward its child, or its rest offset from the upper)
		var ax := (sk.get_bone_global_rest(l).basis.orthonormalized().inverse() * (sk.get_bone_global_rest(l).origin - sk.get_bone_global_rest(u).origin)).normalized()
		var proj := Vector3(q.x, q.y, q.z).dot(ax)
		var tw := Quaternion(ax.x * proj, ax.y * proj, ax.z * proj, q.w).normalized()
		var deg := rad_to_deg(2.0 * acos(clampf(absf(tw.w), 0.0, 1.0)))
		if deg > TWIST_DEG:
			_tell("TWIST", who, String(pair[1]), deg, ctx)


func _tell(kind: String, who: String, bone: String, v: float, ctx: String) -> void:
	var ck := "%s|%s|%s|%s" % [kind, who, bone, ctx]
	_counts[ck] = int(_counts.get(ck, 0)) + 1
	var key := "%s|%s|%s" % [kind, who, bone]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_seen.get(key, -INF)) < 1.0:
		return
	_seen[key] = now
	var fnd := {"el": el_now, "kind": kind, "who": who, "bone": bone, "v": snappedf(v, 0.001), "ctx": ctx}
	findings.append(fnd)
	print("STRETCH ", JSON.stringify(fnd))


func _context(f: Node3D) -> String:
	if f == player:
		var c := SwayCaster.of(player)
		var pz: SwayPose = c.pose if c != null else null
		var cast := "%s/%s" % [pz.anim_name, pz.phase] if pz != null and pz.phase != "" else "-"
		var ring := String(pz.ring_clip()) if pz != null else ""
		var lo: LocoBrain = player.anim.loco if player.anim != null else null
		var kn := BendKnock.peek(player)
		return "cast %s | ring %s | lower %s | %s%s" % [cast, ring if ring != "" else "-", String(lo.state) if lo != null else "-",
				"air" if not player.is_on_floor() else "floor", " | knocked" if kn != null and (kn.is_launched() or kn.knocked_within(0.4)) else ""]
	var body: NpcBody = f.get(&"body") as NpcBody
	return "clip %s | action %s | %s" % [body.clip if body != null else "-", String(f.get(&"action")),
			"air" if not (f as CharacterBody3D).is_on_floor() else "floor"]


func _summary() -> void:
	var keys := _counts.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_counts[a]) > int(_counts[b]))
	var rows: Array = []
	for k: String in keys.slice(0, 60):
		rows.append({"what": k, "frames": _counts[k]})
	var totals := {}
	for k: String in _counts:
		var kind := k.get_slice("|", 0) + "|" + k.get_slice("|", 1)
		totals[kind] = int(totals.get(kind, 0)) + int(_counts[k])
	print("STRETCH_SUMMARY ", JSON.stringify({"frames": _frames, "findings": findings.size(), "totals": totals, "worst": rows}))


func _quit(code: int) -> void:
	if is_instance_valid(sim):
		sim._let_go()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
