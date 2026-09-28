extends AnimTestSuite
## WP6 (plan section 10 test_replay, section 9 recorder): a 20 s scripted session on the whole
## PlayerAnim facade (idle, walk, run, strafe, a quick reversal, aim and fire, a staged reload
## interrupted by a sprint, weapon switches, a jump and landing, crouch, the bow's draw / shot /
## nock / R grab, light and heavy hits, death and respawn, a gameplay-override toggle) is recorded
## from setup with AnimRecorder, then replayed on a fresh PlayerAnim through
## set_input_source(AnimRecorder.replay_source(lines)):
##   - the recording has one line per frame, a header (from_setup, format), every
##     facade event type the session produced and its physics edge events;
##   - the recorder's per-frame pose hash equals the recording run's pose (sha1, 1e-4 quantized);
##   - the replay reproduces every frame's pose hash exactly;
##   - negative control: the same replay without one recorded event diverges.

const FacadeRig := preload("res://tests/anim/facade_rig.gd")
const SECONDS := 20.0
const PATH := "user://anim_test_replay.jsonl"


func describe() -> String:
	return "PlayerAnim recorder: a 20 s scripted session replays to identical per-frame pose hashes"


func timeout_s() -> float:
	return 240.0


func run(ctx: AnimTestContext) -> void:
	var a = FacadeRig.new()
	if not a.setup(ctx, {"weapon": "musket", "record": PATH}):
		return
	ctx.check(a.anim.is_recording(), "recording from setup (%s)" % PATH)
	var n := int(SECONDS * 60.0)
	var own: Array[String] = []
	for i in n:
		_script(a, i)
		own.append(AnimRecorder.pose_hash(a.rig.sk))
	a.anim.stop_recording()
	var header := AnimRecorder.load_header(PATH)
	var lines := AnimRecorder.load(PATH)
	ctx.check(bool(header.get("from_setup", false)) and int(header.get("format", 0)) == AnimRecorder.FORMAT,
			"header: from setup, format %d (%s)" % [AnimRecorder.FORMAT, header.keys()])
	ctx.check(lines.size() == n, "one line per frame (%d of %d)" % [lines.size(), n])
	var same := 0
	for i in mini(n, lines.size()):
		if String(lines[i].get("h", "")) == own[i]:
			same += 1
	ctx.check(same == n, "recorded pose hashes equal the recording run's poses (%d of %d)" % [same, n])
	var kinds := {}
	var edges := {}
	for l: Dictionary in lines:
		for e in l.get("ev", []):
			kinds[String(e.get("t", ""))] = true
		for e in l.get("in", {}).get("events", []):
			edges[String(e.get("t", ""))] = true
	var want := ["weapon", "action", "fired", "cancel", "hurt", "died", "revive", "option"]
	var missing := []
	for k in want:
		if not kinds.has(k):
			missing.append(k)
	ctx.check(missing.is_empty(), "the session records every facade event type %s (missing %s)" % [kinds.keys(), missing])
	ctx.check(edges.has("jumped") and edges.has("landed"), "physics edge events recorded %s" % [edges.keys()])
	var distinct := {}
	for h in own:
		distinct[h] = true
	ctx.check(distinct.size() > n / 2, "the pose changes through the session (%d distinct of %d frames)" % [distinct.size(), n])

	# Replay on a fresh facade.
	var b = FacadeRig.new()
	if not b.setup(ctx, {"weapon": "musket"}):
		return
	b.anim.set_input_source(AnimRecorder.replay_source(lines))
	var bad := 0
	var first := -1
	for i in lines.size():
		b.anim.manual_step(1.0 / 60.0)
		if AnimRecorder.pose_hash(b.rig.sk) != String(lines[i].h):
			bad += 1
			if first < 0:
				first = i
	ctx.check(bad == 0, "replay reproduces every frame's pose hash (%d mismatches, first at frame %d)" % [bad, first])
	ctx.check(b.anim.frame == lines.size(), "replay ran %d frames" % b.anim.frame)

	# Negative control: drop the first fired event; the replay must diverge from there on.
	var cut := lines.duplicate(true)
	var at := -1
	for i in cut.size():
		var ev: Array = cut[i].get("ev", [])
		for k in ev.size():
			if String(ev[k].get("t", "")) == "fired":
				ev.remove_at(k)
				at = i
				break
		if at >= 0:
			break
	var c = FacadeRig.new()
	if not c.setup(ctx, {"weapon": "musket"}):
		return
	c.anim.set_input_source(AnimRecorder.replay_source(cut))
	var diverged := 0
	for i in cut.size():
		c.anim.manual_step(1.0 / 60.0)
		if AnimRecorder.pose_hash(c.rig.sk) != String(cut[i].h):
			diverged += 1
	ctx.check(at >= 0 and diverged > 0, "control: a replay without the fired event at frame %d diverges (%d frames differ)" % [at, diverged])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## The scripted session: frame i of 20 s (the rig faces +Z; local x right, y forward).
func _script(a, i: int) -> void:
	var t := i / 60.0
	var dir := Vector2.ZERO
	var spd := 0.0
	var ex := {}
	if t < 1.0:
		pass
	elif t < 2.0:
		dir = Vector2(0, 1)
		spd = 1.6
	elif t < 3.0:
		dir = Vector2(0, 1)
		spd = 3.6
	elif t < 3.6:
		dir = Vector2(-1, 0)
		spd = 3.6
	elif t < 4.4:
		dir = Vector2(0, -1)
		spd = 3.6
	elif t < 6.0:
		a.aiming = t < 5.4
		if i == 318:
			a.fire()
	elif t < 7.5:
		if i == 360:
			a.action("reload_begin", 1.3)
		if i == 438:
			a.action("reload_mid", 1.6)
	elif t < 8.5:
		# The reload is interrupted by a sprint (Firearm: action_cancelled).
		if i == 450:
			a.cancel()
		a.sprinting = true
		dir = Vector2(0, 1)
		spd = 5.6
	elif t < 10.0:
		a.sprinting = false
		if i == 510:
			a.switch("pistol")
		if i == 540:
			ex = {"jump": true}
		dir = Vector2(1, 1)
		spd = 3.6
	elif t < 12.0:
		a.crouched = t < 11.5
		if i == 600:
			a.anim.override_fast_hemisphere_fade = true
		dir = Vector2(0, 1) if t < 11.0 else Vector2.ZERO
		spd = 1.4
	elif t < 15.5:
		if i == 720:
			a.switch("bow")
		a.aiming = t > 12.8 and t < 13.8
		a.charge = clampf((t - 12.8) / 0.6, 0.0, 1.0) if a.aiming else 0.0
		if i == 828:
			a.fire()
			a.aiming = false
			a.charge = 0.0
			a.action("nock", 0.75)
		if i == 900:
			a.action("grab", 1.1)
	elif t < 18.0:
		if i == 930:
			a.anim.play_hit(Vector2(0, 1), false)
		if i == 990:
			a.anim.play_hit(Vector2(1, 0), true)
		if i == 1050:
			a.alive = false
			a.anim.play_death(Vector2(0, -1))
	else:
		if i == 1080:
			a.alive = true
			a.anim.revive()
		dir = Vector2(0, 1) if t > 18.5 else Vector2.ZERO
		spd = 3.6
	a.step(dir, spd, ex)
