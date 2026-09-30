extends SceneTree
## This project's own unarmed jog (user 2026-09-30: "we use the sprint but matching the jog rhythm for the jog, so not the
## same dramatic swings"). The sprint's motion, retimed onto the jog's stride and phase-matched to its feet, then eased
## part of the way back to the jog's own pose (`k`: 1 is the sprint retimed, 0 the jog): the arms, torso and legs carry
## the sprint's shapes with less of its drive.
##   variants: Godot --headless --path . -s tools/anim_author/author_locomotion.gd -- bake [k=0.55,0.65,0.75]
##             writes animations_extra/Frontier_Locomotion.res (library frontier_locomotion, clips "own-jog-<dir>-k<pct>")
##   speed:    Godot --headless --path . -s tools/anim_author/author_locomotion.gd -- speed [dir=fw,fw-lt,fw-rt] [k=0.75]
##             the travel speed the planted foot gives each variant (the jog and sprint too, as the yardstick)
##   sheet:    Godot --path . -s tools/anim_author/author_locomotion.gd -- sheet out=<dir> [dir=fw] [k=0.55,0.65,0.75]
##             frames of the jog, each variant and the sprint, side view, at the same moments of the gait cycle
## The feet: each direction's sprint is shifted in time until its heel heights (the clip metrics) follow the jog's over
## the cycle; the sprint's two gait cycles (1.33 s) become two of the jog's (0.73 s each).

const CLIPS := "res://animations/Actor_B.res"
const METRICS := "res://animations/actor_b_clip_metrics.json"
const OUT_LIB := "res://animations_extra/Frontier_Locomotion.res"
const WIRED := "res://data/anim_author/locomotion_clips.json"
const FPS := 30.0
## Our own stop: seconds our upper body takes to ease into the graph's stop, and how much faster than the graph's it runs.
const STOP_S := 0.6
const STOP_RATE := 1.12
## Our stop keeps this share of the graph's movement: the arms, the shoulder girdle, the spine.
const STOP_ARMS := 0.4
const STOP_GIRDLE := 0.25
const STOP_SPINE := 0.7
## The forward stops keep almost none of the graph's upper body (user 2026-09-30: "the stop animations going forward I do not like at
## all, make it similar to the back"): its skid throws the arms out and leans the chest back; ours is the jog's upper body settling
## to the standing pose, as the backward one does.
const STOP_FW_UPPER := 0.08
const STOP_FW_SPINE := 0.2
## The jump and fall arms: the share of the graph's arm movement the left arm keeps (the right keeps all of it), and both arms' lag behind the body (s).
const ARMS_SWING := 0.7
const ARMS_LAG := 0.07
## Backward jogs: the share of our upper body's swing they take (the shoulder girdle; the rest).
const BACK_SHOULDER_SWING := 0.12
const BACK_SPINE_SWING := 0.3
const BACK_SWING := 0.6
const OffscreenView := preload("res://tools/environment/offscreen_view.gd")

var args := {}
var lib: AnimationLibrary
var metrics := {}
var _rig: Skeleton3D
var _ap: AnimationPlayer
var wired := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		args[s.get_slice("=", 0)] = s.substr(s.find("=") + 1) if "=" in s else true
	lib = load(CLIPS) as AnimationLibrary
	metrics = JSON.parse_string(FileAccess.get_file_as_string(METRICS)).clips
	if args.has("bake"):
		await _bake()
	elif args.has("sheet"):
		await _sheet()
	elif args.has("rifleside"):
		_rifle_side_preview()
	elif args.has("strip"):
		await _strip()
	elif args.has("speed"):
		await _speed()
	quit()


func _ks() -> Array:
	var out: Array = []
	for s in str(args.get("k", "0.55,0.65,0.75")).split(",", false):
		out.append(float(s))
	return out


static func _name(dir: String, k: float) -> String:
	return "own-jog-%s-k%d" % [dir, int(round(k * 100.0))]


func _bake() -> void:
	var ch := _character()
	_rig = ch[1]
	_ap = ch[2]
	_ap.speed_scale = 0.0
	var out := AnimationLibrary.new()
	var k: float = _ks().back()
	# the forward jogs are the sprint's (see the header); the backward ones are those played in reverse (a backward jog
	# is the forward one run the other way: the backward-left strafe is the forward-right one reversed, and so on)
	var jogs := {}
	for dir in ["fw", "fw-lt", "fw-rt"]:
		var shift: float = await _best_shift(dir, k)
		print("jog ", dir, ": sprint shifted ", snappedf(shift, 0.001), " s")
		jogs[dir] = _blend(dir, k, shift)
	# the backward jogs: the graph's own legs (a forward jog reversed looked wrong: user 2026-09-30) under our upper body, its
	# arm swing and torso twist on the backward jog's own upright posture
	for dir in ["bw", "bw-lt", "bw-rt"]:
		jogs[dir] = _backward(dir, jogs["fw" + dir.trim_prefix("bw")])
	for dir: String in jogs:
		var clip: Animation = jogs[dir]
		out.add_animation(StringName(_name(dir, k)), clip)
		var sp: Array = await _fk_speed(clip)
		wired["actor_b-p-run-" + dir] = {"lib": "frontier_locomotion", "clip": _name(dir, k), "speed": snappedf(sp[0], 0.001), "length": snappedf(clip.length, 0.000001)}
		print("  ", dir, " ", snappedf(sp[0], 0.01), " m/s")
		# the start into it: the graph's own with the new jog eased in
		var start_name: String = "actor_b-p-idle^run-" + dir
		var sn: String = "own-start-%s-k%d" % [dir, int(round(k * 100.0))]
		out.add_animation(StringName(sn), _transition(dir, true, clip, start_name))
		wired[start_name] = {"lib": "frontier_locomotion", "clip": sn, "length": snappedf(lib.get_animation(start_name).length, 0.000001)}
		# the stop out of it: the graph's steps, our own upper body and timing
		var stop_name: String = "actor_b-p-run-" + dir + "^idle"
		var tn: String = "own-stop-%s-k%d" % [dir, int(round(k * 100.0))]
		out.add_animation(StringName(tn), _own_stop(clip, stop_name))
		wired[stop_name] = {"lib": "frontier_locomotion", "clip": tn, "length": snappedf(lib.get_animation(stop_name).length, 0.000001)}
	# the jump and the fall: the graph's body with our own arms (user 2026-09-30: "the jump animation, tweak the arms so it
	# does not look identical")
	for cn in ["actor_b-p-jump-long", "actor_b-p-fall"]:
		var an: String = "own-arms-" + cn.trim_prefix("actor_b-p-")
		out.add_animation(StringName(an), _arms_variant(lib.get_animation(cn)))
		wired[cn] = {"lib": "frontier_locomotion", "clip": an, "length": snappedf(lib.get_animation(cn).length, 0.000001)}
	# the felling axe's carry arm (GatherTools: the last frame of the draw's return, the right arm only, held while the
	# axe is in the hand, walking, sprinting and crouched), as a one-frame pose the spear's sprint and crouch take
	var axe_bones := _bake_axe_carry(out, "own-axe-carry", ["clavicle", "scapula", "shoulder", "deltoid", "elbow", "wrist", "forarm", "trap"])
	var grip_bones := _bake_axe_carry(out, "own-axe-grip", ["palm", "index", "middle", "pinky", "ring", "thumb"])
	# the rifle's own low ready (idle, walking and running backward) and medium ready (crouch walk): the graph's arms turned at the
	# shoulders, the right decides where the gun points and the left hand is the IK's
	var low_bones := _bake_rifle_pose(out, "own-rifle-low-ready", "actor_b-p-rifle-idle-arms", LOW_TURN_R, LOW_TURN_L)
	var mid_bones := _bake_rifle_pose(out, "own-rifle-crouch-mid", "actor_b-p-rifle-crouch-run-arms", MID_TURN_R, MID_TURN_L, HIP_PULL, GUN_YAW_BACK, "actor_b-p-crouch-walk-bw")
	_bake_rifle_pose(out, "own-rifle-crouch-mid-fw", "actor_b-p-rifle-crouch-run-arms", MID_FW_TURN_R, MID_FW_TURN_L, HIP_PULL, GUN_YAW_FW, "actor_b-p-crouch-walk-fw")
	var idle_bones := _bake_rifle_pose(out, "own-rifle-crouch-idle", "actor_b-p-rifle-crouch-idle-arms", Vector3.ZERO, Vector3.ZERO, HIP_PULL_IDLE, GUN_YAW_IDLE, "actor_b-p-crouch-idle")
	_bake_bow_nock_hand(out, "actor_b-p-bow-reload--part", "own-bow-nock-hand")
	_bake_bow_nock_hand(out, "actor_b-p-crouch-bow-reload--part", "own-bow-nock-hand-crouch")
	print(ResourceSaver.save(out, OUT_LIB, ResourceSaver.FLAG_COMPRESS))
	_write_carry_patches(axe_bones, grip_bones, low_bones, mid_bones, idle_bones)
	var f := FileAccess.open(WIRED, FileAccess.WRITE)
	f.store_string(JSON.stringify({"about": "Clips that stand in for the graph's own (AnimGraphData.apply_clip_overrides): the graph clip name -> the library and clip played instead, its measured travel speed (m/s, tools/anim_author/author_locomotion.gd) and length (s). The plant phases and the rest of the metrics stay the original clip's.", "clips": wired}, "\t") + "\n")
	f.close()


## A clip of ours carries the asset id and attribution of the clip it is made from (the baked bank clips keep their sources'
## ids, and a clip of ours has to name one).
static func _stamp(a: Animation, from: Animation) -> Animation:
	for m in [&"native_asset_id", &"source_attribution"]:
		if from.has_meta(m):
			a.set_meta(m, from.get_meta(m))
	return a


const AXE_CARRY_SRC := "res://animations_extra/Actor_B_from_A.res"
const AXE_CARRY_CLIP := "machete-draw--grab^idle--part"
const CARRY_PATCHES := "res://data/anim_author/carry_patches.json"
## The roles a carry on the feet concerns: the direction banks, starts, stops, reversals and turns (not the air, landing, hit and
## death roles, which the weapons' inputs share).
const MOVE_ROLES := ["fw", "fw_lt", "fw_rt", "bw", "bw_lt", "bw_rt", "start_fw", "start_fw_lt", "start_fw_rt", "start_bw", "start_bw_lt",
		"start_bw_rt", "stop_fw", "stop_fw_lt", "stop_fw_rt", "stop_bw", "stop_bw_lt", "stop_bw_rt", "rev_bw_fw", "rev_bw_fw_lt", "rev_bw_fw_rt",
		"rev_fw_bw", "rev_fw_bw_lt", "rev_fw_bw_rt", "turn_l", "turn_r"]


## The felling axe's carry as a one-frame clip `clip_name` in `out` (the last frame of the draw's return, on the bones named
## by `parts`, right side); returns the bones it keys. "own-axe-carry": the arm; "own-axe-grip": the palm and fingers (the
## fist round the haft). The prop bone is left to the game, which places the spear (Throwable).
func _bake_axe_carry(out: AnimationLibrary, clip_name: String, parts: Array) -> Array:
	var src := (load(AXE_CARRY_SRC) as AnimationLibrary).get_animation(AXE_CARRY_CLIP)
	var pose := _stamp(Animation.new(), src)
	pose.length = 1.0 / 30.0
	pose.set_meta(&"authored", "Frontier: the felling axe's carry (%s), the last frame of %s (tools/anim_author/author_locomotion.gd)" % [clip_name, AXE_CARRY_CLIP])
	var bones: Array = []
	for ti in src.get_track_count():
		var type := src.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(src.track_get_path(ti).get_concatenated_subnames())
		var keep := false
		for part in parts:
			if bone.begins_with("r_") and part in bone and not "prop" in bone:
				keep = true
		if not keep:
			continue
		var tr := pose.add_track(type)
		pose.track_set_path(tr, src.track_get_path(ti))
		if not bones.has(bone):
			bones.append(bone)
		if type == Animation.TYPE_ROTATION_3D:
			pose.rotation_track_insert_key(tr, 0.0, src.rotation_track_interpolate(ti, src.length))
		else:
			pose.position_track_insert_key(tr, 0.0, src.position_track_interpolate(ti, src.length))
	out.add_animation(StringName(clip_name), pose)
	return bones


## data/anim_author/carry_patches.json: arm layers the graph's roles get in place of their own (AnimGraphData.apply_carry_patches)
## because the tables cannot be regenerated here; "clips" are graph clips of our own library.
func _write_carry_patches(axe_bones: Array, grip_bones: Array, low_bones: Array, mid_bones: Array, idle_bones: Array) -> void:
	var axe_layer := {"clip": "own-axe-carry", "kind": "partial", "slot": "arms", "status": "frontier", "weight": 1.0,
			"sample_s": 0.0, "bones": axe_bones, "superseded_by": null, "weight_curve": null}
	var grip_layer := {"clip": "own-axe-grip", "kind": "partial", "slot": "hands", "status": "frontier", "weight": 1.0,
			"sample_s": 0.0, "bones": grip_bones, "superseded_by": null, "weight_curve": null}
	var mid_layer := {"clip": "own-rifle-crouch-mid", "kind": "partial", "slot": "arms", "status": "frontier", "weight": 0.8,
			"sample_s": 0.0, "bones": mid_bones, "superseded_by": null, "weight_curve": null}
	var idle_layer := {"clip": "own-rifle-crouch-idle", "kind": "partial", "slot": "arms", "status": "frontier", "weight": 1.0,
			"sample_s": 0.0, "bones": idle_bones, "superseded_by": null, "weight_curve": null}
	var mid_fw_layer := mid_layer.duplicate()
	mid_fw_layer["clip"] = "own-rifle-crouch-mid-fw"
	var doc := {
		"about": "Arm layers the graph's roles take in place of their own (AnimGraphData.apply_carry_patches; written by tools/anim_author/author_locomotion.gd). clips: graph clips of our own library. rules: weapon / modes / roles (all but roles_except) / slots replaced, by layers, or copied from another weapon's same role (copy_from).",
		"clips": {"own-axe-carry": {"lib": "frontier_locomotion", "clip": "own-axe-carry", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-axe-grip": {"lib": "frontier_locomotion", "clip": "own-axe-grip", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-rifle-low-ready": {"lib": "frontier_locomotion", "clip": "own-rifle-low-ready", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-rifle-crouch-mid": {"lib": "frontier_locomotion", "clip": "own-rifle-crouch-mid", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-rifle-crouch-mid-fw": {"lib": "frontier_locomotion", "clip": "own-rifle-crouch-mid-fw", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-rifle-crouch-idle": {"lib": "frontier_locomotion", "clip": "own-rifle-crouch-idle", "length": snappedf(1.0 / 30.0, 0.000001)},
				"own-bow-nock-hand": {"lib": "frontier_locomotion", "clip": "own-bow-nock-hand", "length": snappedf(NOCK_HAND_LEN, 0.000001)},
				"own-bow-nock-hand-crouch": {"lib": "frontier_locomotion", "clip": "own-bow-nock-hand-crouch", "length": snappedf(NOCK_HAND_LEN, 0.000001)}},
		"actions": {
			"bow/stand/nock_hand": {"copy_of": "bow/stand/nock", "frontier_key": "nock_hand", "partial": "own-bow-nock-hand"},
			"bow/crouch/nock_hand": {"copy_of": "bow/crouch/nock", "frontier_key": "nock_hand", "partial": "own-bow-nock-hand-crouch"}},
		"rules": [
			{"why": "the spear sprints and crouches with the felling axe's carry: its arm and its grip (user 2026-09-30: \"hold it like the fell axe\"); its idle keeps the javelin carry",
			"weapon": "spear", "modes": ["sprint"], "roles_except": ["idle"], "roles_only": MOVE_ROLES, "slots": ["arms", "hands"], "layers": [grip_layer, axe_layer]},
			{"why": "the spear crouches with the felling axe's carry: its arm and its grip (user 2026-09-30)",
			"weapon": "spear", "modes": ["crouch"], "roles_except": [], "roles_only": MOVE_ROLES + ["idle"], "slots": ["arms", "hands"], "layers": [grip_layer, axe_layer]},
			{"why": "the rifle crouch walk holds it at medium ready (user 2026-09-30): the crouch run arms turned down at the shoulders (own-rifle-crouch-mid); the left hand is the grip IK's",
			"weapon": "musket", "modes": ["crouch"], "roles_except": ["idle"], "roles_only": BACK_ROLES, "slots": ["arms"], "layers": [mid_layer]},
			{"why": "the rifle crouch idle with the right hand nearer the right hip (user 2026-09-30)",
			"weapon": "musket", "modes": ["crouch"], "roles_except": [], "roles_only": ["idle"], "slots": ["arms"], "layers": [idle_layer]},
			{"why": "the rifle crouch walk forward, medium ready: the same, the arms turned further (the forward crouch walk's torso is more upright)",
			"weapon": "musket", "modes": ["crouch"], "roles_except": ["idle"], "roles_only": FWD_ROLES, "slots": ["arms"], "layers": [mid_fw_layer]},
			{"why": "the pistol stays up through the run's stop (user 2026-09-30: \"instead of the pistol down have it in the pistol up for that split second on the pistol stop\"): the run's own arm on the stops (the graph's stop lowers it to the idle arm)",
			"weapon": "pistol", "modes": ["run"], "roles_except": [], "roles_only": ["stop_fw", "stop_fw_lt", "stop_fw_rt", "stop_bw", "stop_bw_lt", "stop_bw_rt"],
			"slots": ["arms", "arms_add"], "copy_from": "pistol", "copy_mode": "run", "copy_role": "fw"},
			{"why": "the tomahawk crouches like the pistol (user 2026-09-30): the pistol's crouch arm on every role",
			"weapon": "tomahawk", "modes": ["crouch"], "roles_except": [], "slots": ["arms", "arms_add"], "copy_from": "pistol"},
		],
	}
	var f := FileAccess.open(CARRY_PATCHES, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "\t") + "\n")
	f.close()


## Rifle crouch walk "like the aim animation but on the user's side, the right side, low" (user 2026-09-30): the arms of the
## graph's crouched aim walk with both shoulders turned by `rr` / `rl` (degrees, pitch yaw roll in the shoulder's own frame).
const RIFLE_SRC := "actor_b-p-rifle-aim-crouch-walk-fw"
const PREVIEW_LIB := "user://preview_lib.res"


## The aim walk's body clip with its shoulders turned: the preview, and (arms only) the pose the game takes.
func _rifle_side(rr: Vector3, rl: Vector3, arms_only: bool) -> Animation:
	var src := lib.get_animation(RIFLE_SRC)
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = src.loop_mode
	var re := _vec_arg("re")
	var le := _vec_arg("le")
	var turn := {"r_shoulder": Quaternion.from_euler(Vector3(deg_to_rad(rr.x), deg_to_rad(rr.y), deg_to_rad(rr.z))),
			"l_shoulder": Quaternion.from_euler(Vector3(deg_to_rad(rl.x), deg_to_rad(rl.y), deg_to_rad(rl.z))),
			"r_elbow": Quaternion.from_euler(Vector3(deg_to_rad(re.x), deg_to_rad(re.y), deg_to_rad(re.z))),
			"l_elbow": Quaternion.from_euler(Vector3(deg_to_rad(le.x), deg_to_rad(le.y), deg_to_rad(le.z)))}
	var keep := ["clavicle", "scapula", "shoulder", "deltoid", "elbow", "wrist", "forarm", "trap"]
	var n := int(round(src.length * FPS))
	for ti in src.get_track_count():
		var type := src.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(src.track_get_path(ti).get_concatenated_subnames())
		if arms_only:
			var ok := false
			for part in keep:
				if (bone.begins_with("r_") or bone.begins_with("l_")) and part in bone:
					ok = true
			if not ok:
				continue
		var tr := out.add_track(type)
		out.track_set_path(tr, src.track_get_path(ti))
		for f in n + 1:
			var t := minf(float(f) / FPS, src.length)
			if type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = src.rotation_track_interpolate(ti, t)
				if turn.has(bone):
					q = q * (turn[bone] as Quaternion)
				out.rotation_track_insert_key(tr, t, q)
			else:
				out.position_track_insert_key(tr, t, src.position_track_interpolate(ti, t))
	return out


func _vec_arg(key: String) -> Vector3:
	var p := str(args.get(key, "0,0,0")).split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## rifleside rr=x,y,z rl=x,y,z: previews of the turned aim walk into user://preview_lib.res (library "pre", clips "a".."g": the
## variants named by rr / rl lists separated by ';').
func _rifle_side_preview() -> void:
	var out := AnimationLibrary.new()
	var rrs := str(args.get("rr", "0,0,0")).split(";")
	var rls := str(args.get("rl", "0,0,0")).split(";")
	for i in maxi(rrs.size(), rls.size()):
		var a := rrs[mini(i, rrs.size() - 1)].split(",")
		var b := rls[mini(i, rls.size() - 1)].split(",")
		out.add_animation(StringName("v%d" % i), _rifle_side(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(b[0]), float(b[1]), float(b[2])), false))
	print(ResourceSaver.save(out, PREVIEW_LIB))


## The rifle low ready and the crouch walk's medium ready: the turns at the shoulders (degrees, pitch yaw roll in the shoulder's own
## frame: +Y lowers the hand and the gun's end on that side) of the graph's arm poses.
const LOW_TURN_R := Vector3(0.0, 35.0, 0.0)
const LOW_TURN_L := Vector3(0.0, 35.0, 0.0)
const MID_TURN_R := Vector3(0.0, 12.0, 0.0)
const MID_TURN_L := Vector3(0.0, 12.0, 0.0)
## (forward the crouch walk's torso is more upright, so the arms turn further for the same barrel height)
## The share of the way from the right hand to the right hip the crouch poses draw the hand (user 2026-09-30: "close to the hip"
## for the idle, "very close" for the crouch walk).
const HIP_PULL := 0.6
const HIP_PULL_IDLE := 0.45
## The hold points the gun across the body, about 10 o'clock when the hand is at the hip (user 2026-09-30); these turn it (degrees
## about the body's vertical, + to the left) from where the graph's poses leave it (measured in the level: idle 75 deg left of the
## player's facing, walking 52 / 57: 60 is 10 o'clock).
const GUN_YAW_IDLE := -28.0
const GUN_YAW_FW := 8.0
const GUN_YAW_BACK := 3.0
const MID_FW_TURN_R := Vector3(0.0, 32.0, 0.0)
const MID_FW_TURN_L := Vector3(0.0, 32.0, 0.0)
const FWD_ROLES := ["fw", "fw_lt", "fw_rt", "start_fw", "start_fw_lt", "start_fw_rt", "stop_fw", "stop_fw_lt", "stop_fw_rt", "turn_l", "turn_r"]
const BACK_ROLES := ["bw", "bw_lt", "bw_rt", "start_bw", "start_bw_lt", "start_bw_rt", "stop_bw", "stop_bw_lt", "stop_bw_rt",
		"rev_bw_fw", "rev_bw_fw_lt", "rev_bw_fw_rt", "rev_fw_bw", "rev_fw_bw_lt", "rev_fw_bw_rt"]


## A one-frame arms pose `clip_name` in `out`: `src_name`'s arms at its first frame, the shoulders turned by `rr` / `rl`; returns
## the bones it keys.
func _bake_rifle_pose(out: AnimationLibrary, clip_name: String, src_name: String, rr: Vector3, rl: Vector3, hip_pull := 0.0, gun_yaw := 0.0, body_clip := "") -> Array:
	var src := lib.get_animation(src_name)
	var pose := _stamp(Animation.new(), src)
	pose.length = 1.0 / 30.0
	pose.set_meta(&"authored", "Frontier: %s's arms with the shoulders turned (%s; tools/anim_author/author_locomotion.gd)" % [src_name, clip_name])
	var turn := {"r_shoulder": Quaternion.from_euler(Vector3(deg_to_rad(rr.x), deg_to_rad(rr.y), deg_to_rad(rr.z))),
			"l_shoulder": Quaternion.from_euler(Vector3(deg_to_rad(rl.x), deg_to_rad(rl.y), deg_to_rad(rl.z)))}
	var bones: Array = []
	for ti in src.get_track_count():
		var type := src.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(src.track_get_path(ti).get_concatenated_subnames())
		var keep := false
		for part in ["clavicle", "scapula", "shoulder", "deltoid", "elbow", "wrist", "forarm", "trap"]:
			if (bone.begins_with("r_") or bone.begins_with("l_")) and part in bone:
				keep = true
		if not keep:
			continue
		var tr := pose.add_track(type)
		pose.track_set_path(tr, src.track_get_path(ti))
		var q: Quaternion = src.rotation_track_interpolate(ti, 0.0)
		if turn.has(bone):
			q = q * (turn[bone] as Quaternion)
		pose.rotation_track_insert_key(tr, 0.0, q)
		if not bones.has(bone):
			bones.append(bone)
	if hip_pull > 0.0:
		_pull_to_hip(pose, hip_pull, gun_yaw, body_clip)
	out.add_animation(StringName(clip_name), pose)
	return bones


## The right hand of a one-frame arms pose drawn toward the right hip (user 2026-09-30: "the right hand closer to the right hip"):
## the prop bone (the gun's grip) moves `pull` of the way from where it is to the hip joint, keeping its turn, by turning the right
## shoulder, elbow and wrist (a search over their turns on the skeleton: the arm chain is plain forward kinematics). Judged on the
## rest torso: the arms' rotations are the chest's, whatever the body clip under them does.
func _pull_to_hip(pose: Animation, pull: float, gun_yaw := 0.0, body_clip := "") -> void:
	# the chest's turn off the rest pose in the body clip the arms go under (the crouch leans it): the gun's yaw is wanted about the
	# world's vertical, which in the chest's frame is that turned
	var crel := _chest_turn(body_clip)
	_rig.reset_bone_poses()
	var track := {}
	for ti in pose.get_track_count():
		var bone := String(pose.track_get_path(ti).get_concatenated_subnames())
		track[bone] = ti
		_rig.set_bone_pose_rotation(_rig.find_bone(bone), pose.rotation_track_interpolate(ti, 0.0))
	_rig.force_update_all_bone_transforms()
	var prop := _rig.find_bone("r_hand_prop_attachment")
	var g0 := _rig.get_bone_global_pose(prop)
	var hip := _rig.get_bone_global_pose(_rig.find_bone("r_upper_leg")).origin
	var target := g0.origin + (hip - g0.origin) * pull
	var joints := ["r_shoulder", "r_elbow", "r_wrist"]
	var base: Array = []
	for j in joints:
		base.append(_rig.get_bone_pose_rotation(_rig.find_bone(j)))
	var v := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	# (the gun's turn: where it was, turned `gun_yaw` degrees about the body's vertical, + to the left: how the hold points it across the body)
	var d_world := Basis(Vector3.UP, deg_to_rad(gun_yaw))
	var g_want := Transform3D(crel.inverse() * d_world * crel * g0.basis, g0.origin)
	var best := _hip_cost(joints, base, v, g_want, target)
	var step := 10.0
	while step > 0.25:
		var improved := false
		for i in 9:
			for sgn in [1.0, -1.0]:
				var w := v.duplicate()
				w[i] += step * sgn
				var c := _hip_cost(joints, base, w, g_want, target)
				if c < best:
					best = c
					v = w
					improved = true
		if not improved:
			step *= 0.5
	_hip_cost(joints, base, v, g_want, target)
	var after := _rig.get_bone_global_pose(prop)
	print("hip pull %.2f: hand moved %.3f m (asked %.3f), grip %.1f deg off the wanted turn (%.0f asked), cost %.4f" % [pull, (after.origin - g0.origin).length(), (target - g0.origin).length(), rad_to_deg(g_want.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion())), gun_yaw, best])
	for k in joints.size():
		var ti: int = track[joints[k]]
		pose.rotation_track_insert_key(ti, 0.0, _rig.get_bone_pose_rotation(_rig.find_bone(joints[k])))


## How far the chest (the top spine bone) is turned off the rest pose in `body_clip` (averaged over the clip's cycle, a Basis); identity
## for "".
func _chest_turn(body_clip: String) -> Basis:
	if body_clip == "":
		return Basis.IDENTITY
	var a := lib.get_animation(body_clip)
	_rig.reset_bone_poses()
	_rig.force_update_all_bone_transforms()
	var spined := _rig.find_bone("spined")
	var rest := _rig.get_bone_global_pose(spined).basis
	var acc := Vector4.ZERO
	var ref := Quaternion.IDENTITY
	for i in 8:
		_rig.reset_bone_poses()
		var t := a.length * float(i) / 8.0
		for ti in a.get_track_count():
			if a.track_get_type(ti) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := _rig.find_bone(String(a.track_get_path(ti).get_concatenated_subnames()))
			if bone < 0:
				continue
			_rig.set_bone_pose_rotation(bone, a.rotation_track_interpolate(ti, t))
		_rig.force_update_all_bone_transforms()
		var q := (_rig.get_bone_global_pose(spined).basis * rest.inverse()).get_rotation_quaternion()
		if i == 0:
			ref = q
		if q.dot(ref) < 0.0:
			q = Quaternion(-q.x, -q.y, -q.z, -q.w)
		acc += Vector4(q.x, q.y, q.z, q.w)
	acc = acc.normalized()
	_rig.reset_bone_poses()
	return Basis(Quaternion(acc.x, acc.y, acc.z, acc.w))


## The cost of turns `v` (degrees, three per joint) on the arm chain: the grip's distance from the target, plus its turn off where
## it was (the gun must not turn), plus a little for turning the joints at all. Leaves the skeleton posed so.
func _hip_cost(joints: Array, base: Array, v: PackedFloat32Array, g0: Transform3D, target: Vector3) -> float:
	var reg := 0.0
	for k in joints.size():
		var e := Vector3(deg_to_rad(v[k * 3]), deg_to_rad(v[k * 3 + 1]), deg_to_rad(v[k * 3 + 2]))
		_rig.set_bone_pose_rotation(_rig.find_bone(joints[k]), (base[k] as Quaternion) * Quaternion.from_euler(e))
		reg += e.length()
	_rig.force_update_all_bone_transforms()
	var g := _rig.get_bone_global_pose(_rig.find_bone("r_hand_prop_attachment"))
	return (g.origin - target).length() * 4.0 + g0.basis.get_rotation_quaternion().angle_to(g.basis.get_rotation_quaternion()) * 0.6 + reg * 0.01


## The bow's nock with an arrow in the hand (user 2026-09-30: "with arrows in hand the user doesn't need to pull arrows out the
## quiver"): the last part of the graph's reload, the hand already past the quiver and on its way to the string.
const NOCK_HAND_FROM := 0.9
const NOCK_HAND_LEN := 0.3


func _bake_bow_nock_hand(out: AnimationLibrary, src_name: String, clip_name: String) -> void:
	var src := lib.get_animation(src_name)
	var a := _stamp(Animation.new(), src)
	a.length = NOCK_HAND_LEN
	a.loop_mode = Animation.LOOP_NONE
	a.set_meta(&"authored", "Frontier: the end of %s, from %.2f s: the arrow nocked from the bow hand (tools/anim_author/author_locomotion.gd)" % [src_name, NOCK_HAND_FROM])
	var n := int(round(NOCK_HAND_LEN * FPS))
	for ti in src.get_track_count():
		var type := src.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var tr := a.add_track(type)
		a.track_set_path(tr, src.track_get_path(ti))
		for f in n + 1:
			var t := minf(float(f) / FPS, NOCK_HAND_LEN)
			var ts := minf(NOCK_HAND_FROM + t, src.length)
			if type == Animation.TYPE_ROTATION_3D:
				a.rotation_track_insert_key(tr, t, src.rotation_track_interpolate(ti, ts))
			else:
				a.position_track_insert_key(tr, t, src.position_track_interpolate(ti, ts))
	out.add_animation(StringName(clip_name), a)


## A clip with its arms made our own: each arm bone's movement about its mean through the clip is scaled (ARMS_SWING) and
## run ARMS_LAG seconds behind the body's, the left arm a little less than the right, so the arms no longer trace the graph's
## path at the graph's moments. Everything else is the graph's.
func _arms_variant(a: Animation) -> Animation:
	var out := _stamp(Animation.new(), a)
	out.length = a.length
	out.loop_mode = a.loop_mode
	out.set_meta(&"authored", "Frontier: the graph's body with our own arms (tools/anim_author/author_locomotion.gd)")
	var arm := ["clavicle", "scapula", "shoulder", "deltoid", "elbow", "wrist", "forarm", "trap"]
	var n := int(round(a.length * FPS))
	for ti in a.get_track_count():
		var type := a.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := a.track_get_path(ti)
		var bone := String(path.get_concatenated_subnames())
		var tr := out.add_track(type)
		out.track_set_path(tr, path)
		var is_arm := type == Animation.TYPE_ROTATION_3D and (bone.begins_with("l_") or bone.begins_with("r_"))
		if is_arm:
			is_arm = false
			for part in arm:
				if part in bone:
					is_arm = true
		var mean := _mean_q(a, ti) if is_arm else Quaternion.IDENTITY
		# (the right arm keeps its reach, the graph's: the spear and the torch ride it, and pulling it in puts them in the thigh)
		var scale := ARMS_SWING if bone.begins_with("l_") else 1.0
		for f in n + 1:
			var t := minf(float(f) / FPS, a.length)
			if type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = a.rotation_track_interpolate(ti, t)
				if is_arm:
					# (a looping clip lags round its loop, so the seam stays closed)
					var tl := fposmod(t - ARMS_LAG, a.length) if a.loop_mode != Animation.LOOP_NONE else maxf(t - ARMS_LAG, 0.0)
					var lagged: Quaternion = a.rotation_track_interpolate(ti, tl)
					q = mean * Quaternion.IDENTITY.slerp(mean.inverse() * lagged, scale)
				out.rotation_track_insert_key(tr, t, q)
			else:
				out.position_track_insert_key(tr, t, a.position_track_interpolate(ti, t))
	return out


## A clip played backwards (a loop stays a loop).
func _reversed(a: Animation) -> Animation:
	var r := _stamp(Animation.new(), a)
	r.length = a.length
	r.loop_mode = a.loop_mode
	r.set_meta(&"authored", "Frontier: a forward jog played backwards (tools/anim_author/author_locomotion.gd)")
	var n := int(round(a.length * FPS))
	for ti in a.get_track_count():
		var type := a.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var tr := r.add_track(type)
		r.track_set_path(tr, a.track_get_path(ti))
		for f in n + 1:
			var t := minf(float(f) / FPS, a.length)
			var src := fposmod(a.length - t, a.length) if t < a.length else 0.0
			if type == Animation.TYPE_ROTATION_3D:
				r.rotation_track_insert_key(tr, t, a.rotation_track_interpolate(ti, src))
			else:
				r.position_track_insert_key(tr, t, a.position_track_interpolate(ti, src))
	return r


## Our own stop: the graph's steps (its legs and hips, as they are) with our own upper body and timing. The jog's upper body
## (its lean, arm swing and torso twist, slowing as the gait does) eases into the graph's stop over STOP_S seconds; the whole
## stop runs STOP_RATE times as fast, holding its last pose (the standing pose) for the rest of the graph's length, which the
## tables time the state by.
func _own_stop(new_jog: Animation, orig_name: String) -> Animation:
	var orig := lib.get_animation(orig_name)
	var big := orig.length
	var phase := _match_phase(orig, 0.0, new_jog)
	var out := _stamp(Animation.new(), orig)
	out.length = big
	out.set_meta(&"authored", "Frontier: the graph's steps, our own upper body and timing (tools/anim_author/author_locomotion.gd; %s)" % orig_name)
	var n := int(round(big * FPS))
	var ph: Array = []
	var p := phase * new_jog.length
	for f in n + 1:
		ph.append(p)
		p += (1.0 - smoothstep(0.0, STOP_S, float(f) / FPS)) / FPS
	var upper := _upper_bones()
	for ti in orig.get_track_count():
		var type := orig.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := orig.track_get_path(ti)
		var bone := String(path.get_concatenated_subnames())
		var ji := new_jog.find_track(path, type)
		var tr := out.add_track(type)
		out.track_set_path(tr, path)
		# (the graph's stop throws the arms out as it settles: ours moves them less, about the standing pose it rests in)
		var damp := _stop_damp(bone, "run-fw" in orig_name) if upper.has(bone) else 1.0
		var rest_q := orig.rotation_track_interpolate(ti, big) if type == Animation.TYPE_ROTATION_3D else Quaternion.IDENTITY
		for f in n + 1:
			var t := minf(float(f) / FPS, big)
			var ts := minf(t * STOP_RATE, big)
			var w := smoothstep(0.0, STOP_S, t)
			var mix := upper.has(bone) and ji >= 0
			if type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = orig.rotation_track_interpolate(ti, ts)
				if damp < 1.0:
					q = rest_q * Quaternion.IDENTITY.slerp(rest_q.inverse() * q, damp)
				if mix:
					q = new_jog.rotation_track_interpolate(ji, fposmod(float(ph[f]), new_jog.length)).slerp(q, w)
				out.rotation_track_insert_key(tr, t, q)
			else:
				out.position_track_insert_key(tr, t, orig.position_track_interpolate(ti, ts))
	return out


## How much of the graph's stop movement our stop keeps, by bone: the arms much less, the shoulder girdle less still, the
## spine a little less (user 2026-09-30: "we don't move the arms as much").
static func _stop_damp(bone: String, forward := false) -> float:
	for part in ["clavicle", "scapula", "deltoid", "trap"]:
		if part in bone:
			return STOP_FW_UPPER if forward else STOP_GIRDLE
	for part in ["shoulder", "elbow", "wrist", "forarm"]:
		if part in bone:
			return STOP_FW_UPPER if forward else STOP_ARMS
	for part in ["spine", "chest", "neck"]:
		if part in bone:
			return STOP_FW_SPINE if forward else STOP_SPINE
	return 1.0


## How much of our swing the backward jog takes, by bone (user 2026-09-30: "backwards shoulders too exaggerated, tone it
## down"): the shoulder girdle least, the arms and spine most.
static func _swing_scale(bone: String) -> float:
	for part in ["clavicle", "scapula", "shoulder", "deltoid", "trap"]:
		if part in bone:
			return BACK_SHOULDER_SWING
	# (the spine's twist is what sways the shoulders: much less of it too)
	for part in ["spine", "chest", "neck"]:
		if part in bone:
			return BACK_SPINE_SWING
	return BACK_SWING


## The bones of the upper body (the clip metrics' bone set).
func _upper_bones() -> Dictionary:
	var out := {}
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(METRICS))
	for b in m.bone_sets.upper:
		out[String(b)] = true
	return out


## The mean rotation of a track over a clip.
static func _mean_q(a: Animation, ti: int) -> Quaternion:
	var acc := Vector4.ZERO
	var ref := a.rotation_track_interpolate(ti, 0.0)
	for i in 24:
		var q := a.rotation_track_interpolate(ti, a.length * float(i) / 24.0)
		if q.dot(ref) < 0.0:
			q = Quaternion(-q.x, -q.y, -q.z, -q.w)
		acc += Vector4(q.x, q.y, q.z, q.w)
	acc = acc.normalized()
	return Quaternion(acc.x, acc.y, acc.z, acc.w)


## A backward jog: the graph's own (legs, hips, everything below the chest) with the upper body of our forward jog `fwd` worked
## in: each upper bone's swing about its own mean (how far it moves from where it sits through the cycle) is ours, the mean
## stays the backward jog's (it stands upright with its hands held in), and the swing is timed against the backward legs
## as the original's arms are (the time shift whose swing is nearest the original's).
func _backward(dir: String, fwd: Animation) -> Animation:
	var bw := lib.get_animation("actor_b-p-run-" + dir)
	var upper := _upper_bones()
	var out := _stamp(Animation.new(), bw)
	out.length = bw.length
	out.loop_mode = Animation.LOOP_LINEAR
	out.set_meta(&"authored", "Frontier: the graph's backward legs under our upper body's swing (tools/anim_author/author_locomotion.gd)")
	# the timing of our swing against the legs: the shift whose swing is nearest the original's over the arms and spine
	var swing_bones := ["l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "spinea", "spineb", "spinec", "spined"]
	var best := 1e9
	var shift := 0.0
	for i in 48:
		var sh := bw.length * float(i) / 48.0
		var cost := 0.0
		for bone in swing_bones:
			var path := NodePath("Skeleton3D:" + bone)
			var bi := bw.find_track(path, Animation.TYPE_ROTATION_3D)
			var fi := fwd.find_track(path, Animation.TYPE_ROTATION_3D)
			if bi < 0 or fi < 0:
				continue
			var bm := _mean_q(bw, bi)
			var fm := _mean_q(fwd, fi)
			for j in 12:
				var t := bw.length * float(j) / 12.0
				var db: Quaternion = bm.inverse() * bw.rotation_track_interpolate(bi, t)
				var df: Quaternion = fm.inverse() * fwd.rotation_track_interpolate(fi, fposmod(t + sh, fwd.length))
				cost += db.angle_to(df)
		if cost < best:
			best = cost
			shift = sh
	print("backward ", dir, ": our swing shifted ", snappedf(shift, 0.001), " s")
	var n := int(round(bw.length * FPS))
	for ti in bw.get_track_count():
		var type := bw.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := bw.track_get_path(ti)
		var bone := String(path.get_concatenated_subnames())
		var fi := fwd.find_track(path, type)
		var tr := out.add_track(type)
		out.track_set_path(tr, path)
		var swing := type == Animation.TYPE_ROTATION_3D and upper.has(bone) and fi >= 0
		var bm := _mean_q(bw, ti) if swing else Quaternion.IDENTITY
		var fm := _mean_q(fwd, fi) if swing else Quaternion.IDENTITY
		for f in n + 1:
			var t := minf(float(f) / FPS, bw.length)
			if type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = bw.rotation_track_interpolate(ti, t)
				if swing:
					var delta: Quaternion = fm.inverse() * fwd.rotation_track_interpolate(fi, fposmod(t + shift, fwd.length))
					q = bm * Quaternion.IDENTITY.slerp(delta, _swing_scale(bone))
				out.rotation_track_insert_key(tr, t, q)
			else:
				out.position_track_insert_key(tr, t, bw.position_track_interpolate(ti, t))
	return out


## The phase (0..1) of `jog` whose pose is nearest the pose of `a` at `at`.
func _match_phase(a: Animation, at: float, jog: Animation) -> float:
	var best := 1e9
	var phase := 0.0
	for i in 44:
		var u := float(i) / 44.0
		var d := _pose_dist(a, clampf(at, 0.0, a.length - 0.001), jog, u * jog.length)
		if d < best:
			best = d
			phase = u
	return phase


## Seconds to shift the sprint clip so its feet meet the jog's: the two heel-height curves (both feet) over one gait
## cycle, the jog's against each of the sprint's two cycles, scaled to the same range; the shift with the least
## difference. Returns seconds into the sprint clip where the jog's cycle begins.
func _phase_shift(jog: String, sprint: String) -> float:
	var hj: Dictionary = metrics[jog].heel_z
	var hs: Dictionary = metrics[sprint].heel_z
	var sl: float = lib.get_animation(sprint).length
	var cycle := sl / float(int(metrics[sprint].travel.cycles))
	var best := 1e9
	var best_s := 0.0
	for i in 200:
		var u := float(i) / 200.0
		var err := 0.0
		for foot in ["l", "r"]:
			var a: Array = _norm(hj[foot])
			var b: Array = _norm(hs[foot])
			for j in 24:
				var p := float(j) / 24.0
				err += pow(_samp(a, p) - _samp(b, fposmod(u + p, 1.0) / float(int(metrics[sprint].travel.cycles))), 2.0)
		if err < best:
			best = err
			best_s = u * cycle
	return best_s


## A heel-height curve as zero mean and unit spread (the last sample repeats the first: dropped).
static func _norm(v: Array) -> Array:
	var a: Array = v.slice(0, v.size() - 1)
	var mean := 0.0
	for x in a:
		mean += float(x)
	mean /= a.size()
	var sd := 0.0
	for x in a:
		sd += pow(float(x) - mean, 2.0)
	sd = maxf(sqrt(sd / a.size()), 1e-4)
	return a.map(func(x: float) -> float: return (x - mean) / sd)


## A looped curve at phase p in [0, 1).
static func _samp(a: Array, p: float) -> float:
	var f := fposmod(p, 1.0) * a.size()
	var i := int(floor(f))
	var w := f - i
	return lerpf(float(a[i % a.size()]), float(a[(i + 1) % a.size()]), w)


## One clip: the jog's two cycles long, every bone the sprint's, eased back toward the jog by (1 - k).
func _blend(dir: String, k: float, shift: float) -> Animation:
	var jog := lib.get_animation("actor_b-p-run-" + dir)
	var spr := lib.get_animation("actor_b-p-sprint-" + dir)
	var cycles := int(metrics["actor_b-p-sprint-" + dir].travel.cycles)
	var cyc := spr.length / float(cycles)
	var length := jog.length
	var anim := _stamp(Animation.new(), spr)
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.set_meta(&"authored", "Frontier: the sprint's motion at the jog's stride, k=%.2f (tools/anim_author/author_locomotion.gd)" % k)
	var n := int(round(length * FPS))
	for t_i in jog.get_track_count():
		var type := jog.track_get_type(t_i)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := jog.track_get_path(t_i)
		var s_i := spr.find_track(path, type)
		var tr := anim.add_track(type)
		anim.track_set_path(tr, path)
		for f in n + 1:
			var t := minf(float(f) / FPS, length)
			var u := t / length
			var tj := u * jog.length
			var ts := shift + u * cyc
			if type == Animation.TYPE_ROTATION_3D:
				var qj: Quaternion = jog.rotation_track_interpolate(t_i, tj)
				var q := qj
				if s_i >= 0:
					q = qj.slerp(_sprint_q(spr, s_i, ts, cyc, cycles), k)
				anim.rotation_track_insert_key(tr, t, q)
			else:
				var pj: Vector3 = jog.position_track_interpolate(t_i, tj)
				var p := pj
				if s_i >= 0:
					p = pj.lerp(_sprint_p(spr, s_i, ts, cyc, cycles), k)
				anim.position_track_insert_key(tr, t, p)
	return anim


## A start (idle into the jog) or stop (the jog into idle) of the graph with the new jog in it: where the clip meets the jog
## (its last frame for a start, its first for a stop) the pose is the new jog's, at the phase the original jog would be
## in there (the pose of the clip matched to the original jog's poses over its cycle); away from it the clip is the
## graph's own, eased over part of its length so no old jog shows before the new one.
func _transition(dir: String, is_start: bool, new_jog: Animation, orig_name: String) -> Animation:
	var orig := lib.get_animation(orig_name)
	var jog := new_jog
	var big := orig.length
	var at := big if is_start else 0.0
	var phase := _match_phase(orig, at, new_jog)
	var out := _stamp(Animation.new(), orig)
	out.length = big
	out.set_meta(&"authored", "Frontier: the graph's %s with the new jog eased in (tools/anim_author/author_locomotion.gd)" % orig_name)
	var n := int(round(big * FPS))
	for ti in orig.get_track_count():
		var type := orig.track_get_type(ti)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := orig.track_get_path(ti)
		var ji := new_jog.find_track(path, type)
		var tr := out.add_track(type)
		out.track_set_path(tr, path)
		for f in n + 1:
			var t := minf(float(f) / FPS, big)
			var tj := fposmod(phase * jog.length - (big - t), jog.length) if is_start else fposmod(phase * jog.length + t, jog.length)
			var w := smoothstep(big * 0.4, big, t) if is_start else 1.0 - smoothstep(0.0, big * 0.4, t)
			if type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = orig.rotation_track_interpolate(ti, t)
				if ji >= 0:
					q = q.slerp(new_jog.rotation_track_interpolate(ji, tj), w)
				out.rotation_track_insert_key(tr, t, q)
			else:
				var p: Vector3 = orig.position_track_interpolate(ti, t)
				if ji >= 0:
					p = p.lerp(new_jog.position_track_interpolate(ji, tj), w)
				out.position_track_insert_key(tr, t, p)
	return out


## Sum of the angles between the legs' and spine's rotations in two clips at two moments.
func _pose_dist(a: Animation, ta: float, b: Animation, tb: float) -> float:
	var d := 0.0
	for bone in ["l_upper_leg", "l_knee", "r_upper_leg", "r_knee", "l_ankle", "r_ankle", "spine"]:
		var path := NodePath("Skeleton3D:" + bone)
		var i := a.find_track(path, Animation.TYPE_ROTATION_3D)
		var j := b.find_track(path, Animation.TYPE_ROTATION_3D)
		if i >= 0 and j >= 0:
			d += a.rotation_track_interpolate(i, ta).angle_to(b.rotation_track_interpolate(j, tb))
	return d


## The sprint's pose at phase `ts` with its gait cycles averaged (the two of them differ a little: one cycle of the
## mean loops without a seam).
static func _sprint_q(spr: Animation, i: int, ts: float, cyc: float, cycles: int) -> Quaternion:
	var q: Quaternion = spr.rotation_track_interpolate(i, fposmod(ts, spr.length))
	for c in range(1, cycles):
		q = q.slerp(spr.rotation_track_interpolate(i, fposmod(ts + c * cyc, spr.length)), 1.0 / float(c + 1))
	return q


static func _sprint_p(spr: Animation, i: int, ts: float, cyc: float, cycles: int) -> Vector3:
	var p: Vector3 = spr.position_track_interpolate(i, fposmod(ts, spr.length))
	for c in range(1, cycles):
		p = p.lerp(spr.position_track_interpolate(i, fposmod(ts + c * cyc, spr.length)), 1.0 / float(c + 1))
	return p


# --- contact sheet -----------------------------------------------------------------------------------------------

func _character() -> Array:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(n)
	var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	CharacterBodyMesh.attach(sk, aps[0] if not aps.is_empty() else null, "res://assets/character/actor_b_body.glb")
	return [n, sk, aps[0]]


func _sheet() -> void:
	var out := str(args.get("out", "user://locomotion"))
	var dir := str(args.get("dir", "fw"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var ch := _character()
	var ap := ch[2] as AnimationPlayer
	ap.speed_scale = 0.0
	var own := load(OUT_LIB) as AnimationLibrary
	var variants: Array = []      # [label, library key, clip, cycle length s]
	var jog_len := lib.get_animation("actor_b-p-run-" + dir).length
	variants.append(["jog", "actor_b", "actor_b-p-run-" + dir, jog_len])
	for k in _ks():
		variants.append(["k%d" % int(round(k * 100.0)), "own", _name(dir, k), jog_len])
	var spr_len := lib.get_animation("actor_b-p-sprint-" + dir).length / float(int(metrics["actor_b-p-sprint-" + dir].travel.cycles))
	variants.append(["sprint", "actor_b", "actor_b-p-sprint-" + dir, spr_len])
	ap.add_animation_library("own", own)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(260, 360))
	var cam: Camera3D = view.camera
	cam.fov = 38.0
	await process_frame
	await process_frame
	var frames := int(args.get("frames", 8))
	for v in variants:
		ap.play("%s/%s" % [v[1], v[2]])
		for f in frames:
			ap.seek(float(f) / float(frames) * float(v[3]), true)
			var sk := ch[1] as Skeleton3D
			sk.force_update_all_bone_transforms()
			var base := Vector3(0, 0.95, 0)
			cam.global_position = base + Vector3(-3.3, 0.25, 0.0)
			cam.look_at(base)
			for i in 3:
				await process_frame
			view.get_texture().get_image().save_png("%s/%s_%d.png" % [out, v[0], f])
	print("SHEET ", out, " ", variants.map(func(v: Array) -> String: return v[0]))


# --- travel speed ------------------------------------------------------------------------------------------------

## Body speed (m/s) from the planted foot: of the two heels the lower one is planted (within 2 cm of the lowest height
## of the cycle), and it slides back at the body's speed. The same estimate on the jog reads what the clip metrics
## give it (3.34), the yardstick.
func _clip_speed(ap: AnimationPlayer, sk: Skeleton3D, path: String, length: float) -> float:
	ap.play(path)
	var dt := 1.0 / 60.0
	var n := int(round(length / dt))
	var lo := 1e9
	var pts: Array = []
	for f in n + 1:
		ap.seek(minf(float(f) * dt, length), true)
		await process_frame
		sk.force_update_all_bone_transforms()
		var row: Array = []
		for foot in ["l_heel", "r_heel"]:
			var g := sk.get_bone_global_pose(sk.find_bone(foot)).origin
			row.append(g)
			lo = minf(lo, g.y)
		pts.append(row)
	var v: Array = []
	for f in n:
		for i in 2:
			var a: Vector3 = pts[f][i]
			var b: Vector3 = pts[f + 1][i]
			# (the lower heel of the pair, near the cycle's lowest: planted)
			if a.y < lo + 0.05 and b.y < lo + 0.05 and a.y <= pts[f][1 - i].y:
				v.append(Vector2(b.x - a.x, b.z - a.z).length() / dt)
	v.sort()
	return float(v[v.size() / 2]) if not v.is_empty() else 0.0


func _speed() -> void:
	var ch := _character()
	var ap := ch[2] as AnimationPlayer
	ap.speed_scale = 0.0
	ap.add_animation_library("own", load(OUT_LIB) as AnimationLibrary)
	for dir in str(args.get("dir", "fw,fw-lt,fw-rt")).split(",", false):
		var rows: Array = [["jog", "actor_b/actor_b-p-run-" + dir], ["sprint", "actor_b/actor_b-p-sprint-" + dir]]
		for k in _ks():
			rows.append(["k%d" % int(round(k * 100.0)), "own/" + _name(dir, k)])
		for r in rows:
			var len := ap.get_animation(r[1]).length
			print("SPEED %-7s %-6s %.2f m/s" % [dir, r[0], await _clip_speed(ap, ch[1], r[1], len)])


## The shift, tried over the sprint's cycle, whose blend at `k` keeps the jog's own legs in step: the legs' poses (both thighs,
## knees and ankles) nearest the original jog's over the whole cycle. The graph's forward, forward-left and forward-right
## jogs start on the same foot phase, and the direction banks blend them at the same moment of the cycle; a shift chosen
## for each alone (the planted foot's steadiness) put them out of step and the diagonals crossed the legs.
func _best_shift(dir: String, k: float) -> float:
	var jog := lib.get_animation("actor_b-p-run-" + dir)
	var spr := lib.get_animation("actor_b-p-sprint-" + dir)
	var cycle := spr.length / float(int(metrics["actor_b-p-sprint-" + dir].travel.cycles))
	var best := 1e9
	var best_s := 0.0
	var steps := 60
	for i in steps:
		var sh := cycle * float(i) / float(steps)
		var clip := _blend(dir, k, sh)
		var cost := 0.0
		for j in 24:
			var t := clip.length * float(j) / 24.0
			cost += _leg_dist(clip, t, jog, t)
		if args.has("debug"):
			print("  shift ", snappedf(sh, 0.001), " leg distance ", snappedf(cost / 24.0, 0.001))
		if cost < best:
			best = cost
			best_s = sh
	return best_s


## Sum of the angles between the legs' rotations in two clips at two moments.
func _leg_dist(a: Animation, ta: float, b: Animation, tb: float) -> float:
	var d := 0.0
	for bone in ["l_upper_leg", "l_knee", "l_ankle", "r_upper_leg", "r_knee", "r_ankle"]:
		var path := NodePath("Skeleton3D:" + bone)
		var i := a.find_track(path, Animation.TYPE_ROTATION_3D)
		var j := b.find_track(path, Animation.TYPE_ROTATION_3D)
		if i >= 0 and j >= 0:
			d += a.rotation_track_interpolate(i, ta).angle_to(b.rotation_track_interpolate(j, tb))
	return d


## [travel speed, spread] of a clip by the planted heel (see _clip_speed): the clip played on the character (the heels
## are placed by the rig's modifiers, so it takes frames), sampled at 30 Hz.
func _fk_speed(a: Animation) -> Array:
	var dt := 1.0 / 30.0
	var n := int(round(a.length / dt))
	var tmp := AnimationLibrary.new()
	tmp.add_animation(&"c", a)
	if _ap.has_animation_library("cand"):
		_ap.remove_animation_library("cand")
	_ap.add_animation_library("cand", tmp)
	_ap.play("cand/c")
	var lh := _rig.find_bone("l_heel")
	var rh := _rig.find_bone("r_heel")
	var pts: Array = []
	var lo := 1e9
	for f in n + 1:
		_ap.seek(minf(float(f) * dt, a.length), true)
		await process_frame
		_rig.force_update_all_bone_transforms()
		var row := [_rig.get_bone_global_pose(lh).origin, _rig.get_bone_global_pose(rh).origin]
		pts.append(row)
		lo = minf(lo, minf(row[0].y, row[1].y))
	var v: Array = []
	for f in n:
		for i in 2:
			var p: Vector3 = pts[f][i]
			var q: Vector3 = pts[f + 1][i]
			if p.y < lo + 0.05 and q.y < lo + 0.05 and p.y <= pts[f][1 - i].y:
				v.append(Vector2(q.x - p.x, q.z - p.z).length() / dt)
	if v.is_empty():
		return [0.0, 9.0]
	v.sort()
	var med: float = v[v.size() / 2]
	var dev: Array = v.map(func(x: float) -> float: return absf(x - med))
	dev.sort()
	return [med, dev[dev.size() / 2]]


## strip: Godot --path . -s tools/anim_author/author_locomotion.gd -- strip out=<dir> rows=label=lib/clip,... [frames=8]
## frames across each whole clip, side view, one PNG per row and frame (label_<n>.png)
func _strip() -> void:
	var out := str(args.get("out", "user://locomotion"))
	DirAccess.make_dir_recursive_absolute(out)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75)
	e.ambient_light_energy = 0.6
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	var ch := _character()
	var ap := ch[2] as AnimationPlayer
	ap.speed_scale = 0.0
	ap.add_animation_library("own", load(OUT_LIB) as AnimationLibrary)
	if ResourceLoader.exists(PREVIEW_LIB):
		ap.add_animation_library("pre", ResourceLoader.load(PREVIEW_LIB, "", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary)
	var view = OffscreenView.new()
	root.add_child(view)
	view.setup(root, Vector2i(260, 360))
	var cam: Camera3D = view.camera
	cam.fov = 38.0
	await process_frame
	await process_frame
	var frames := int(args.get("frames", 8))
	# rifle=1: a stand-in musket on the right hand's prop bone (barrel along the prop's +Z) and the stock end
	var rifle: MeshInstance3D = null
	var armpit: MeshInstance3D = null
	var have_local := false
	var rifle_local := Vector3.FORWARD
	if args.has("rifle"):
		rifle = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.07, 1.4)
		rifle.mesh = bm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.45, 0.25, 0.1)
		rifle.material_override = rm
		world.add_child(rifle)
		armpit = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.04
		sm.height = 0.08
		armpit.mesh = sm
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(0.9, 0.1, 0.1)
		armpit.material_override = am
		world.add_child(armpit)
	var front := str(args.get("view", "side")) == "front"
	var top := str(args.get("view", "side")) == "top"
	for row in str(args.rows).split(",", false):
		var label := row.get_slice("=", 0)
		var path := row.get_slice("=", 1)
		# "arms:<clip>" in place of the row's own arms: a preview of `ours` = body clip + arm tracks of our pose
		ap.play(path)
		var length := ap.get_animation(path).length
		for f in frames:
			ap.seek(float(f) / float(frames - 1) * length * 0.999, true)
			var skel := ch[1] as Skeleton3D
			skel.force_update_all_bone_transforms()
			if rifle != null:
				# (the gun rides the right hand's prop bone, as the game hangs it; the left hand is the IK's, it closes on the
				# gun wherever the right puts it: the barrel's way in the prop's frame is the aim pose's hand-to-hand line)
				var prop_xf := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("r_hand_prop_attachment"))
				if not have_local:
					var rp0 := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("r_palm"))).origin
					var lp0 := (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("l_palm"))).origin
					rifle_local = prop_xf.basis.inverse() * (lp0 - rp0).normalized()
					have_local = true
				var d := (prop_xf.basis * rifle_local).normalized()
				var rp := prop_xf.origin
				var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
				var bz := d
				var bx := up.cross(bz).normalized()
				var by := bz.cross(bx)
				rifle.global_transform = Transform3D(Basis(bx, by, bz), rp + d * 0.4)
				if armpit != null:
					armpit.global_position = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("r_shoulder"))).origin + Vector3(0, -0.11, 0)
			var base := Vector3(0, 0.95, 0)
			var off := Vector3(-3.3, 0.25, 0.0)
			if front:
				off = Vector3(0.0, 0.25, 3.3)
			elif top:
				off = Vector3(0.0, 3.3, 0.6)
			cam.global_position = base + off
			cam.look_at(base)
			for i in 3:
				await process_frame
			if args.has("debug"):
				print(label, f, " t ", snappedf(ap.current_animation_position, 0.01), " anim ", ap.current_animation, " active ", ap.active, " leg ", (ch[1] as Skeleton3D).get_bone_pose_rotation((ch[1] as Skeleton3D).find_bone("l_upper_leg")))
			view.get_texture().get_image().save_png("%s/%s_%d.png" % [out, label, f])
	print("STRIP ", out)
