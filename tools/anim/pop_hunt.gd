extends SceneTree
## Pop hunt (the animation quality pass of 2026-10-10, the owner: "a animation quality re run make sure they are smooth"): real
## % ring matches, headless, the player played by the film's expert input model (tools/ring/highlight_input.gd: ordinary key
## and mouse actions) against a real bot of another element; every physics frame each fighter's key bones are sampled in its
## skeleton's own space (the pose alone: no travel, no turn), once a drawn frame, and a POP is a one-frame jump: a step over POP_M that is SPIKE_X times the
## larger of the steps either side (a fast strike moves far on every frame and is no pop). Each pop is told with what was
## playing: the player's cast clip and its phase (SwayPose), its lower-body state (LocoBrain) and knock; a bot's clip and
## action. Frames where a fighter moved over TELEPORT_M (a respawn, a ring-out reset) are skipped.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/anim/pop_hunt.gd -- [elements=earth,water,fire,air]
##       [seconds=90] [seed=4100] [out=<file.json>]
## Lines: POP {json} for each, POP_SUMMARY {json} (by element and context, the worst first), POP HUNT DONE.

const InputPlayer := preload("res://tools/ring/highlight_input.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const OWN_CFG := "user://pop_hunt.cfg"
const BONES := ["l_wrist", "r_wrist", "l_elbow", "r_elbow", "l_ankle", "r_ankle", "l_knee", "r_knee", "heada", "pelvis",
		"spinec", "l_shoulder", "r_shoulder"]
const POP_M := 0.06
## A turn of the visual body against the root this large in one frame (rad), and a spike, is a "frame" pop.
const FRAME_RAD := 0.35
const SPIKE_X := 3.0
const FLOOR_M := 0.012
const TELEPORT_M := 2.0
const FOES := {"earth": "water", "water": "fire", "fire": "air", "air": "earth"}
## Drawn frames a second (run with --fixed-fps 60): the poses are sampled once a drawn frame, as they update (the physics
## ticks at 120, so sampled per tick every other step reads 0 and every move looks like a spike).
const FPS := 60.0

var elements: Array = ["earth", "water", "fire", "air"]
var seconds := 90.0
var seed_n := 4100
var out := ""
var mode: RingMode
var level: RingLevel
var player: FrontierPlayer
var sim: Node
var pops: Array = []
var frames_seen := {}
## a bot's instance id -> [its AnimationPlayer's animation, its time] last frame
var _ap_last := {}
## fighter instance id -> {bones: {name: [prev_pos, step_prev2, step_prev1, ctx_prev]}, root: Vector3}
var _track := {}


func _initialize() -> void:
	var a := CaptureKit.args({"elements": ",".join(elements), "seconds": str(seconds), "seed": str(seed_n), "out": ""})
	elements = Array(String(a.elements).split(",", false))
	seconds = float(a.seconds)
	seed_n = int(a.seed)
	out = String(a.out)
	create_timer(seconds * elements.size() + 240.0, true, false, true).timeout.connect(func() -> void:
		print("POP HUNT FAILED (watchdog)")
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
		print("POP HUNT FAILED: no match")
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
	print("POP HUNT DONE")
	_quit(0)


func _hunt(el: String, sd: int) -> void:
	if is_instance_valid(sim):
		sim._let_go()
		sim.free()
	sim = InputPlayer.new()
	sim.setup(player, mode, "expert", sd)
	level.add_child(sim)
	_track.clear()
	var n := int(seconds * FPS)
	var done := 0
	while done < n:
		await process_frame                        # (a pose updates once a drawn frame: physics ticks twice as often)
		if mode.phase != "FIGHT":
			if mode.phase in ["DONE", "END", "RESULT"]:
				mode.restart()
			_track.clear()
			continue
		done += 1
		for f: Node3D in _fighters():
			_sample(el, f)
	frames_seen[el] = done


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


func _sample(el: String, f: Node3D) -> void:
	var sk := _skeleton(f)
	if sk == null or not is_instance_valid(sk) or not sk.is_visible_in_tree():
		return
	var id := f.get_instance_id()
	var t: Dictionary = _track.get(id, {})
	var root := f.global_position
	if t.has("root") and (t.root as Vector3).distance_to(root) > TELEPORT_M:
		t = {}                                     # (a respawn or reset: start again)
	t["root"] = root
	var bt: Dictionary = t.get("bones", {})
	var ctx := _context(f)
	# the visual body against the fighter's root (a body turned or tumbled at once: its own kind of pop, "frame")
	var rel := (f.global_transform.affine_inverse() * sk.global_transform).basis.get_rotation_quaternion()
	if t.has("rel"):
		var a1 := (t.rel as Quaternion).angle_to(rel)
		var fr: Array = t.get("frame", [-1.0, -1.0, ""])
		if float(fr[1]) > FRAME_RAD and float(fr[0]) >= 0.0 and float(fr[1]) > SPIKE_X * maxf(maxf(float(fr[0]), a1), 0.02):
			var fp := {"el": el, "who": "player" if f == player else String(f.name), "bone": "frame", "step_m": snappedf(float(fr[1]), 0.001),
					"ratio": snappedf(float(fr[1]) / maxf(maxf(float(fr[0]), a1), 0.02), 0.1), "ctx": fr[2], "t": 0.0}
			pops.append(fp)
			print("POP ", JSON.stringify(fp))
		t["frame"] = [fr[1], a1, ctx]
	t["rel"] = rel
	for bn: String in BONES:
		var bi := sk.find_bone(bn)
		if bi < 0:
			continue
		var p := sk.get_bone_global_pose(bi).origin       # (in the skeleton's own space: the pose alone)
		var rec: Array = bt.get(bn, [])
		if rec.is_empty():
			bt[bn] = [p, -1.0, -1.0, ctx]
			continue
		var step := p.distance_to(rec[0])
		# the frame before (rec[2], its context rec[3]) is a pop when it jumped and its neighbours did not
		var s1 := float(rec[2])
		var s0 := float(rec[1])
		if s1 > POP_M and s0 >= 0.0 and s1 > SPIKE_X * maxf(maxf(s0, step), FLOOR_M):
			var pop := {"el": el, "who": "player" if f == player else String(f.name), "bone": bn, "step_m": snappedf(s1, 0.001),
					"ratio": snappedf(s1 / maxf(maxf(s0, step), FLOOR_M), 0.1), "ctx": rec[3], "t": snappedf(Time.get_ticks_msec() / 1000.0, 0.01)}
			pops.append(pop)
			print("POP ", JSON.stringify(pop))
		bt[bn] = [p, s1, step, ctx]
	t["bones"] = bt
	_track[id] = t


## What was playing on `f` this frame (the pop is told with the frame it jumped on).
func _context(f: Node3D) -> String:
	if f == player:
		var c := SwayCaster.of(player)
		var pz: SwayPose = c.pose if c != null else null
		var cast := "%s/%s" % [pz.anim_name, pz.phase] if pz != null and pz.phase != "" else "-"
		var lo: LocoBrain = player.anim.loco if player.anim != null else null
		var kn := BendKnock.peek(player)
		return "cast %s | lower %s | %s%s" % [cast, String(lo.state) if lo != null else "-", "air" if not player.is_on_floor() else "floor",
				" | knocked" if kn != null and (kn.is_launched() or kn.knocked_within(0.4)) else ""]
	var body: NpcBody = f.get(&"body") as NpcBody
	var at := ""
	var how := ""
	if body != null and body.ap != null and body.ap.current_animation != "":
		var ln := maxf(body.ap.current_animation_length, 0.001)
		var ps := body.ap.current_animation_position
		at = " | %s" % ("start" if ps < 0.1 else ("end" if ps > ln - 0.1 else "mid"))
		# (what the player did this frame: the same clip on its own clock, a new clip, or a jump in its time: a seek or a wrap)
		var id := f.get_instance_id()
		var last: Array = _ap_last.get(id, [])
		var cur := String(body.ap.current_animation)
		if not last.is_empty():
			if String(last[0]) != cur:
				how = " | switched from %s" % String(last[0]).get_file()
			else:
				var adv := ps - float(last[1])
				var want := body.ap.speed_scale / FPS * 2.0
				if adv < -0.05:
					how = " | wrapped" if float(last[1]) > ln - 0.15 else " | seeked back"
				elif adv > want * 3.0 + 0.02:
					how = " | seeked on"
		_ap_last[id] = [cur, ps]
	return "clip %s%s%s | action %s | %s" % [body.clip if body != null else "-", at, how, String(f.get(&"action")),
			"air" if not (f as CharacterBody3D).is_on_floor() else "floor"]


func _summary() -> void:
	var by := {}
	for p: Dictionary in pops:
		var key := "%s %s | %s" % [p.el, p.who if p.who == "player" else "bot", p.ctx]
		var e: Dictionary = by.get(key, {"n": 0, "max_m": 0.0, "bones": {}})
		e.n += 1
		e.max_m = maxf(float(e.max_m), float(p.step_m))
		(e.bones as Dictionary)[p.bone] = int((e.bones as Dictionary).get(p.bone, 0)) + 1
		by[key] = e
	var keys := by.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(by[a].n) * float(by[a].max_m) > int(by[b].n) * float(by[b].max_m))
	var rows: Array = []
	for k: String in keys:
		rows.append({"ctx": k, "n": by[k].n, "max_m": snappedf(float(by[k].max_m), 0.001), "bones": by[k].bones})
	var per_min := {}
	for el: String in frames_seen:
		var n_el := pops.filter(func(p: Dictionary) -> bool: return p.el == el).size()
		per_min[el] = snappedf(n_el / maxf(float(frames_seen[el]) / FPS / 60.0, 1e-3), 0.1)
	var summary := {"pops": pops.size(), "per_minute": per_min, "worst": rows.slice(0, 40)}
	print("POP_SUMMARY ", JSON.stringify(summary))
	if out != "":
		var fh := FileAccess.open(out, FileAccess.WRITE)
		if fh != null:
			fh.store_string(JSON.stringify({"summary": summary, "pops": pops}, "\t"))


func _quit(code: int) -> void:
	if is_instance_valid(sim):
		sim._let_go()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	GameSettings.path = GameSettings.PATH
	quit(code)
