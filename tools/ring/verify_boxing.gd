extends SceneTree
## VERIFY (read-only reviewer probe, loadouts B1): Boxing against the element's own clips through the real SwayPose, stepped by hand
## at 60 Hz on the player's own SwayCaster in the ring scene.
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/ring/verify_boxing.gd
## For every Boxing pick (and the other hand), the same cast is driven twice: the player a Classic fire caster, then wearing Boxing
## (meta fighting_style). Measured per cast: the clip that plays; strike_wait() at the moment the lock lets go; the frame the pose says
## `struck` (counted from the release); the frame the pose ends (the caster stops being rooted then); the frames rooting() is true;
## the clip time showing at the strike frame. Boxing must equal Classic frame for frame on every timing; its clip's own strike must be
## showing at the strike frame. Also: a fire bot is never given the style, Capoeira never applies, the library is loaded lazily.
## Lines VBOX ...; ends "VERIFY BOXING PASSED (n checks)" / FAILED.

const NAME := "VERIFY BOXING"
const LIB := "res://animations_extra/Frontier_Style_Boxing.res"
const DT := 1.0 / 60.0

var checks := 0
var fails: Array[String] = []
var player: FrontierPlayer
var sc: SwayCaster
var pose: SwayPose
var frame_struck := -1
var frame := 0


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _initialize() -> void:
	seed(1750)
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	SwayCaster.free_override = true
	InputSetup.ensure()
	MatchSetup.incoming = true
	MatchSetup.element = "fire"
	MatchSetup.foes = ["fire"]
	MatchSetup.round_s = 60.0
	MatchSetup.rounds_to_win = 1
	MatchSetup.difficulty = "normal"
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _end() -> void:
	BendLoadout.config_override = {}
	print("%s %s (%d checks, %d failed)" % [NAME, "PASSED" if fails.is_empty() and checks > 0 else "FAILED", checks, fails.size()])
	quit(0 if fails.is_empty() and checks > 0 else 1)


func _on_struck(_m: String) -> void:
	if frame_struck < 0:
		frame_struck = frame


## Drives one cast of (m, md) with `again` earlier casts of the same move first (the combo window: the other hand). Returns the
## measurements of the last.
func _cast(m: String, md: String, again: int) -> Dictionary:
	var out := {}
	sc.modes[m] = md
	sc._pin_id = m                                 # (the mode forced as a quick cast's pin is: hidden modes, the Pop, too)
	sc._pin_mode = md
	sc._pinning = true
	for rep in again + 1:
		pose._stop()
		pose.set_process(false)
		frame_struck = -1
		frame = 0
		pose._on_started(m, null)
		out["clip"] = pose.anim_name
		out["mode_seen"] = sc.mode_of(m)
		out["pick_from"] = String(pose.pick.get("from", "element"))
		out["hold_s"] = float(pose.pick.get("hold_s", -1.0))
		out["strike_s"] = float(pose.pick.get("strike_s", -1.0))
		out["back_s"] = float(pose.pick.get("back_s", -1.0))
		out["end_s"] = float(pose.pick.get("end_s", -1.0))
		out["root_pick"] = bool(pose.pick.get("root", false))
		var hold := float(pose.pick.get("hold_s", 0.3))
		# the lock runs a little longer than the wind-up
		var n_press := int(ceil((hold + 0.15) / DT))
		for i in n_press:
			pose._process(DT)
		out["wait"] = pose.strike_wait()
		out["pressed"] = pose.pressed
		pose.struck.connect(_on_struck, CONNECT_ONE_SHOT)
		pose._on_cast(m, null)
		out["phase"] = pose.phase
		if rep < again:
			# (the first of a combo: the next lock begins while its clip still plays)
			for j in 6:
				pose._process(DT)
			if pose.struck.is_connected(_on_struck):
				pose.struck.disconnect(_on_struck)
			continue
		var root_frames := 0
		var last_phase := pose.phase
		var layer_t := -1.0
		var end_frame := -1
		var guard := 0
		while pose.phase != "" and guard < 600:
			frame += 1
			pose._process(DT)
			guard += 1
			if pose.rooting():
				root_frames += 1
			if frame == frame_struck and not pose._cast_layers.is_empty():
				var l0: Dictionary = pose._cast_layers[0]
				if l0.has("time"):
					layer_t = float(l0.time)
			last_phase = pose.phase
		end_frame = frame
		out["struck_frame"] = frame_struck
		out["end_frame"] = end_frame
		out["root_frames"] = root_frames
		out["layer_t"] = layer_t
		if pose.struck.is_connected(_on_struck):
			pose.struck.disconnect(_on_struck)
		last_phase = last_phase
	sc._pinning = false
	sc._pin_id = ""
	sc._pin_mode = ""
	return out


func _run() -> void:
	for i in 20:
		await process_frame
	var lvl := current_scene as RingLevel
	player = lvl.player if lvl != null else null
	var mode := RingMode.find(self)
	if mode == null or player == null or mode.foe == null:
		_expect(false, "the ring with a player and a bot")
		return _end()
	await physics_frame
	sc = SwayCaster.of(player)
	pose = sc.pose if sc != null else null
	_expect(sc != null and pose != null, "the player has a SwayCaster and a SwayPose")
	if pose == null:
		return _end()
	var bot: NpcFighter = mode.foe
	BendLoadout.config_override = {}
	_expect(BendLoadout.style_meta(player) == "" and not BendPoses._libs.has(LIB), "Classic player: no style, the Boxing library not loaded (lazy)")
	var t0 := Time.get_ticks_usec()
	var fighting := JSON.parse_string(FileAccess.get_file_as_string("res://data/bending/style_poses.json")).styles.boxing as Dictionary
	var picks: Array = []
	for mv: String in fighting.modes:
		for md: String in fighting.modes[mv]:
			var has_alt: bool = (fighting.modes[mv][md] is Dictionary and (fighting.modes[mv][md] as Dictionary).has("alt"))
			picks.append([mv, md, false])
			if has_alt:
				picks.append([mv, md, true])
	var cmp_frames := 0
	var rooted_picks := 0
	for pk: Array in picks:
		var mv := String(pk[0])
		var md := String(pk[1])
		var combo: bool = pk[2]
		BendLoadout.clear(player)
		var classic := _cast(mv, md, 1 if combo else 0)
		BendLoadout.wear(player, [], "boxing", "fire")
		var t_load := Time.get_ticks_usec()
		var box := _cast(mv, md, 1 if combo else 0)
		var load_ms := float(Time.get_ticks_usec() - t_load) / 1000.0
		BendLoadout.clear(player)
		var tag := "%s/%s%s" % [mv, md, " (other hand)" if combo else ""]
		print("VBOX %s classic=%s strike@%d end@%d root=%d wait=%.4f | boxing=%s strike@%d end@%d root=%d wait=%.4f layer_t=%.3f first-cast %.1f ms" % [tag, classic.clip,
				classic.struck_frame, classic.end_frame, classic.root_frames, classic.wait, box.clip, box.struck_frame, box.end_frame, box.root_frames, box.wait, box.layer_t, load_ms])
		_expect(String(classic.mode_seen) == md and String(box.mode_seen) == md, "%s: the pose was started in mode %s (%s, %s)" % [tag, md, classic.mode_seen, box.mode_seen])
		_expect(String(classic.clip).begins_with("own-bend-") and String(box.clip).begins_with("own-style-boxing-"), "%s: Classic plays %s, Boxing %s" % [tag, classic.clip, box.clip])
		_expect(int(classic.struck_frame) >= 0 and int(box.struck_frame) == int(classic.struck_frame), "%s: the strike lands on frame %d (Classic %d)" % [tag, box.struck_frame, classic.struck_frame])
		_expect(absf(float(box.wait) - float(classic.wait)) < 0.0001, "%s: the effect waits %.4f s for the strike (Classic %.4f)" % [tag, box.wait, classic.wait])
		_expect(int(box.end_frame) == int(classic.end_frame), "%s: the pose ends on frame %d (Classic %d)" % [tag, box.end_frame, classic.end_frame])
		_expect(int(box.root_frames) == int(classic.root_frames), "%s: the caster is rooted %d frames (Classic %d)" % [tag, box.root_frames, classic.root_frames])
		if int(classic.root_frames) > 0:
			rooted_picks += 1
		for k: String in ["hold_s", "strike_s", "back_s"]:
			_expect(absf(float(box[k]) - float(classic[k])) < 0.0005, "%s: pick %s %.3f == Classic %.3f" % [tag, k, box[k], classic[k]])
		# the clip's own strike is showing on the strike frame
		var clip_anim := BendPoses.animation(String(box.clip))
		var own := float(clip_anim.get_meta(&"strike_s")) if clip_anim != null and clip_anim.has_meta(&"strike_s") else -1.0
		if own >= 0.0 and float(box.layer_t) >= 0.0:
			_expect(absf(float(box.layer_t) - own) <= 2.5 * DT, "%s: on the strike frame the Boxing clip shows %.3f s, its own strike %.3f s" % [tag, box.layer_t, own])
		cmp_frames += 1
	_expect(rooted_picks >= 2, "the two rooted picks (kick, high kick) were measured rooted (%d)" % rooted_picks)
	_expect(BendPoses._libs.has(LIB) and BendPoses._libs[LIB] != null, "the Boxing library is loaded after the first Boxing pick")
	print("VBOX measured %d casts; whole run %.0f ms" % [cmp_frames, float(Time.get_ticks_usec() - t0) / 1000.0])

	# the bot and Capoeira
	var bp := BendPoses.pick("fire_jab", "embers", "fire", bot)
	_expect(String(bp.clip) == "own-bend-fire-sweep" and BendLoadout.style_meta(bot) == "", "the fire bot plays the element's own embers clip (%s)" % bp.clip)
	BendLoadout.config_override = {"styles_live": ["boxing", "capoeira"]}
	bot.set_meta(BendLoadout.STYLE_META, "capoeira")
	player.set_meta(BendLoadout.STYLE_META, "capoeira")
	_expect(BendPoses.style_of(bot, "air") == "" and BendPoses.style_of(player, "air") == "" and BendPoses.style_of(player, "fire") == "",
			"Capoeira never applies, even listed live and put on a body by hand")
	bot.remove_meta(BendLoadout.STYLE_META)
	player.remove_meta(BendLoadout.STYLE_META)
	BendLoadout.config_override = {}
	# a Boxing body that casts as another element is picked from that element's own clips
	player.set_meta(BendLoadout.STYLE_META, "boxing")
	_expect(String(BendPoses.pick("air_blast", "slice", "air", player).get("from", "")) != "style", "a Boxing body casting an air move plays the element's own clip")
	player.remove_meta(BendLoadout.STYLE_META)
	_end()
