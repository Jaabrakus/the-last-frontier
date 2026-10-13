extends SceneTree
## Bot clip hand-off probe (the animation quality pass, 2026-10-11): a practice ring's standing dummy (an NpcBody on its
## manual AnimationPlayer) is put from its idle into a clip three ways, and the largest one-frame step of its key bones, in
## its skeleton's own space (the pose alone, no turning or travel), is printed for the first frames after each:
##   play_once   NpcBody.play_once (ap.play with its blend, then seek to 0)
##   play_only   ap.play with the same blend, no seek
##   struck      NpcBody.show_struck (the contact pose at its hold_s)
## Headless:
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/anim/npc_blend_probe.gd -- [clip=own-bend-lie]
## Lines: BLEND <way> <clip> steps [..] max <m>; ends NPC BLEND DONE.

const FxStage := preload("res://tools/fx/fx_stage.gd")
const CaptureKit := preload("res://tools/ui_audit/capture_kit.gd")
const BONES := ["l_wrist", "r_wrist", "l_ankle", "r_ankle", "heada", "pelvis", "l_elbow", "r_elbow", "l_knee", "r_knee"]

var st: FxStage
var clips: Array = ["own-bend-lie", "own-bend-fall", "own-bend-hit-impact-front"]


func _initialize() -> void:
	var a := CaptureKit.args({"clip": ""})
	if String(a.clip) != "":
		clips = [String(a.clip)]
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("NPC BLEND FAILED (watchdog)")
		quit(2))
	st = FxStage.new(self)
	st.start("earth")
	_run.call_deferred()


func _run() -> void:
	if not await st.wait_fight():
		print("NPC BLEND FAILED: no fight")
		quit(1)
		return
	await st.reset()
	var f := st.mode.foe
	var body: NpcBody = f.get(&"body") as NpcBody
	if body == null:
		print("NPC BLEND FAILED: no body")
		quit(1)
		return
	for c: String in clips:
		for way: String in ["play_once", "play_only", "struck"]:
			body.play_loop("idle", 0.0) if body.has_method(&"play_loop") else null
			await _frames(20)
			var prev := _pose(body.sk)
			match way:
				"play_once":
					body.play_once(c, 0.08)
				"play_only":
					body._add_pose(c)
					body.ap.play(NpcBody.LIB + "/" + c, 0.08)
				"struck":
					body.show_struck(c)
			var steps: Array = []
			for i in 8:
				await process_frame
				var now := _pose(body.sk)
				var big := 0.0
				for k: String in now:
					big = maxf(big, (now[k] as Vector3).distance_to(prev[k]))
				prev = now
				steps.append(snappedf(big, 0.001))
			print("BLEND %s %s steps %s max %.3f" % [way, c, steps, steps.max()])
			body.bridge = ""
	# a cast sped up to strike at its wind (NpcBody.play_cast: its rate also shortens the blend in real time)
	for wind: float in [0.6, 0.25, 0.12]:
		body.play_once("own-bend-hit-impact-front", 0.1)
		await _frames(6)
		var prev3 := _pose(body.sk)
		var rate := body.play_cast("fire_blast", "punch", wind, "fire")
		var steps3: Array = []
		for i in 8:
			await process_frame
			var now3 := _pose(body.sk)
			var big3 := 0.0
			for k: String in now3:
				big3 = maxf(big3, (now3[k] as Vector3).distance_to(prev3[k]))
			prev3 = now3
			steps3.append(snappedf(big3, 0.001))
		print("CAST wind %.2f rate %.2f steps %s" % [wind, rate, steps3])
	# a gait switch straight on the AnimationPlayer: the blend alone, and the blend with a seek after it (NpcBody.play's
	# phase-matched entry in the ring)
	for way: String in ["blend", "blend+seek", "speeds+seek", "speeds+seek+entry"]:
		body.ap.speed_scale = 1.6 if way.begins_with("speeds") else 1.0
		body.ap.play(NpcBody.LIB + "/walk", 0.0)
		await _frames(30)
		var prev4 := _pose(body.sk)
		var ph := fposmod(body.ap.current_animation_position / body.ap.current_animation_length, 1.0)
		if way.begins_with("speeds"):
			body.ap.speed_scale = 0.6
		body.ap.play(NpcBody.LIB + "/run", NpcBody._real_blend(0.25, body.ap.speed_scale))
		if way == "blend+seek" or way == "speeds+seek":
			body.ap.seek(0.4 * body.ap.current_animation_length, false)
		elif way == "speeds+seek+entry":
			body.ap.seek(NpcBody._step_entry("walk", "run", ph) * body.ap.current_animation_length, false)
		var steps4: Array = []
		for i in 14:
			await process_frame
			var now4 := _pose(body.sk)
			var big4 := 0.0
			for k: String in now4:
				big4 = maxf(big4, (now4[k] as Vector3).distance_to(prev4[k]))
			prev4 = now4
			steps4.append(snappedf(big4, 0.001))
		print("GAIT %s walk->run steps %s" % [way, steps4])
	# the run's direction switches (NpcBody.play: its loops, its blend, the ring's phase-matched entry)
	for pair: Array in [["run", "run_lt"], ["run_lt", "run_rt"], ["run_rt", "run"], ["run", "sprint"], ["idle", "run"]]:
		body.play(String(pair[0]))
		await _frames(25)
		var prev2 := _pose(body.sk)
		body.play(String(pair[1]))
		var steps2: Array = []
		for i in 14:
			await process_frame
			var now2 := _pose(body.sk)
			var big2 := 0.0
			for k: String in now2:
				big2 = maxf(big2, (now2[k] as Vector3).distance_to(prev2[k]))
			prev2 = now2
			steps2.append(snappedf(big2, 0.001))
		print("LOOP %s -> %s steps %s" % [pair[0], pair[1], steps2])
	print("NPC BLEND DONE")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _pose(sk: Skeleton3D) -> Dictionary:
	var out := {}
	for bn: String in BONES:
		var bi := sk.find_bone(bn)
		if bi >= 0:
			out[bn] = sk.get_bone_global_pose(bi).origin
	return out
