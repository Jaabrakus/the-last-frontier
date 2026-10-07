extends SceneTree
## Tidebreak's crowd (round 4 SHOW; RingCrowd, shaders/ring/ring_crowd.gdshader, data/ring/crowd.json; RingDressing.react,
## RingLevel._follow), built as RingDressing builds it on the stock ring's stands:
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_ring_crowd.gd
##   the build    six pose MultiMeshes (idle, lean, arms up, clap, flag, parasol) and a lighter one of each pose for the far
##                view, never both drawn (visibility ranges): at most 8 draws at any distance; the triangles within 2.5x the
##                round-3 crowd's (crowd.json base_tris); each far mesh lighter than its near one; seeded (built twice,
##                every fan the same); each fan's height and build within build_var
##   reactions    a launch sets the ooh; a fall at the -X end starts the ripple there (its origin that end, its time running,
##                fans at that end up before the far end's), at the +X end there; sudden death stands half of them and
##                claps on the ring score's beat (the shader's beat is MusicDirector.ring_beat); calm sits them
##   positions    the crowd never reads a competitor's position: RingCrowd and RingDressing.react read none, and
##                RingLevel._follow tells it only the fall's end (RingRules' record)
## METRIC crowd_react_ok, crowd_draws, crowd_tris. Watchdog LIMIT_S; last line "RING CROWD PASSED" or "RING CROWD FAILED"
## (exit 0 only on a pass).

const NAME := "RING CROWD"
const LIMIT_S := 240.0
const OWN_CFG := "user://ring_crowd_test.cfg"

var checks := 0
var fails: Array[String] = []
var react_ok := true


func _expect(ok: bool, what: String, react := false) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)
		if react:
			react_ok = false


func _initialize() -> void:
	seed(1750)
	create_timer(LIMIT_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	MatchSetup._aim_help = "strong"
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await process_frame


func _make(parent: Node3D) -> RingCrowd:
	var sd: Dictionary = RingArena.data().get("surround", {})
	var skip: Array = []
	for k in 11:
		skip.append(-31.8 + float(k) * 6.36)
	return RingCrowd.make(parent, sd, 31.8, 20.8, 0.0, [Color(0.12, 0.34, 0.72), Color(0.78, 0.16, 0.06)], skip)


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var crowd := _make(holder)
	await _ticks(2)
	_build(crowd)
	await _seeded(holder, crowd)
	await _reactions(crowd)
	await _beat(crowd)
	_positions()
	var draws := _max_draws(crowd)
	print("METRIC crowd_react_ok=%s" % str(react_ok).to_lower())
	print("METRIC crowd_draws=%d" % draws)
	print("METRIC crowd_tris=%d crowd_tris_far=%d crowd_tris_base=%d" % [crowd.triangles(false), crowd.triangles(true),
			int(RingCrowd.num("base_tris", 111500.0))])
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		for f in fails:
			print("  FAIL " + f)
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _mmis(crowd: RingCrowd, far: bool) -> Array:
	var out: Array = []
	for c: Node in crowd.get_children():
		if c is MultiMeshInstance3D and String(c.name).ends_with("Far") == far:
			out.append(c)
	return out


## The most crowd MultiMeshes drawn at any distance from its middle (the visibility ranges).
func _max_draws(crowd: RingCrowd) -> int:
	var most := 0
	for d: float in [0.0, 5.0, 12.0, 20.0, 26.0, 26.9, 27.1, 28.0, 35.0, 50.0, 90.0, 200.0]:
		var n := 0
		for mi: MultiMeshInstance3D in _mmis(crowd, false) + _mmis(crowd, true):
			var b := mi.visibility_range_begin
			var e := mi.visibility_range_end
			if d >= b and (e <= 0.0 or d < e):
				n += 1
		most = maxi(most, n)
	return most


func _build(crowd: RingCrowd) -> void:
	var near := _mmis(crowd, false)
	var far := _mmis(crowd, true)
	_expect(near.size() == 6 and far.size() == 6, "six pose MultiMeshes and a far one of each (%d, %d)" % [near.size(), far.size()])
	var names: Array = near.map(func(m: Node) -> String: return String(m.name))
	_expect(names == ["Idle", "Lean", "ArmsUp", "Clap", "Flag", "Parasol"], "the poses: %s" % str(names))
	var fans := 0
	for mi: MultiMeshInstance3D in near:
		fans += mi.multimesh.instance_count
		_expect(mi.multimesh.instance_count > 20, "%s: %d fans" % [mi.name, mi.multimesh.instance_count])
	_expect(fans == crowd.count and fans > 700, "every fan in one pose (%d of %d)" % [fans, crowd.count])
	var draws := _max_draws(crowd)
	_expect(draws <= 8, "at most 8 crowd draws at any distance (%d)" % draws)
	var t_near := crowd.triangles(false)
	var t_far := crowd.triangles(true)
	var base := int(RingCrowd.num("base_tris", 111500.0))
	_expect(t_near <= int(2.5 * base), "the crowd's triangles %d within 2.5x round 3's %d (%.2fx)" % [t_near, base, float(t_near) / base])
	for p: String in RingCrowd.POSES:
		_expect(int(crowd.tris_far[p]) < int(crowd.tris_near[p]), "%s: far mesh lighter (%d < %d tris)" % [p, crowd.tris_far[p], crowd.tris_near[p]])
	# height and build within build_var (the basis' column lengths)
	var bv := RingCrowd.num("build_var", 0.08)
	var ok := true
	var spread := Vector2(INF, -INF)
	for fans_of: Array in crowd.placed:
		for e: Array in fans_of:
			var b := (e[0] as Transform3D).basis
			var h := b.y.length()
			var w := b.x.length()
			spread = Vector2(minf(spread.x, h), maxf(spread.y, h))
			if absf(h - 1.0) > bv + 0.001 or absf(w - 1.0) > bv + 0.001:
				ok = false
	_expect(ok and spread.y - spread.x > bv, "heights and builds vary within ±%d%% (heights %.3f..%.3f)" % [int(bv * 100.0), spread.x, spread.y])
	_expect(near[0].material_override is ShaderMaterial and (near[0].material_override as ShaderMaterial).shader.resource_path == RingCrowd.SHADER,
			"the crowd's own shader")
	var code := (near[0].material_override as ShaderMaterial).shader.code
	_expect(code.contains("void light()") and code.contains("wrap") and not code.contains("unshaded"), "lit: lambert with wrap, not unshaded")


func _seeded(holder: Node3D, crowd: RingCrowd) -> void:
	var again := _make(holder)
	await _ticks(1)
	var same := crowd.placed.size() == 6 and again.placed.size() == 6
	for i in mini(crowd.placed.size(), again.placed.size()):
		var pa: Array = crowd.placed[i]
		var pb: Array = again.placed[i]
		if pa.size() != pb.size() or (crowd.get_child(i * 2) as MultiMeshInstance3D).multimesh.instance_count != pa.size():
			same = false
			break
		for k in pa.size():
			if not (pa[k][0] as Transform3D).is_equal_approx(pb[k][0]) or not (pa[k][1] as Color).is_equal_approx(pb[k][1]) \
					or not (pa[k][2] as Color).is_equal_approx(pb[k][2]):
				same = false
				break
	_expect(same, "seeded: the crowd built twice is the same crowd")
	again.queue_free()


## The shader's rise for a fan at `x` (the crowd's local) t s after a fall at end `side` (its formula, for the test).
func _rise(crowd: RingCrowd, x: float, t: float) -> float:
	var o: Vector3 = crowd.param(&"ripple_origin")
	var ax: Vector3 = crowd.param(&"ripple_axis")
	var d := absf((crowd.to_global(Vector3(x, 0.0, 20.0)) - o).dot(ax))
	var tr := t - d / float(crowd.param(&"ripple_mps"))
	var rs := float(crowd.param(&"rise_s"))
	var hs := float(crowd.param(&"hold_s"))
	var ss := float(crowd.param(&"sit_s"))
	var near := 1.0 - 0.65 * smoothstep(0.0, float(crowd.param(&"reach_m")), d)
	return float(crowd.param(&"ripple_k")) * near * smoothstep(0.0, rs, tr) * (1.0 - smoothstep(rs + hs, rs + hs + ss, tr))


func _reactions(crowd: RingCrowd) -> void:
	crowd.react("launch", -1, 1.0)
	await _ticks(12)
	_expect(float(crowd.param(&"ooh")) > 0.3, "a launch: the ooh (%.2f)" % float(crowd.param(&"ooh")), true)
	await _ticks(150)
	_expect(float(crowd.param(&"ooh")) < 0.01, "the ooh passes (%.2f)" % float(crowd.param(&"ooh")), true)
	crowd.react("fall", 0, 1.0)
	var o0: Vector3 = crowd.param(&"ripple_origin")
	_expect(o0.is_equal_approx(crowd.to_global(Vector3(-31.8, 0.0, 0.0))), "a fall at the -X end: the ripple starts there (%s)" % str(o0), true)
	_expect(is_equal_approx(float(crowd.param(&"ripple_k")), 1.0), "its strength set", true)
	await _ticks(30)
	var t := float(crowd.param(&"ripple_t"))
	_expect(t > 0.3 and t < 0.7, "its time runs (%.2f s)" % t, true)
	var r_near := _rise(crowd, -28.0, 0.8)
	var r_far := _rise(crowd, 28.0, 0.8)
	_expect(r_near > 0.9 and r_far < 0.05, "0.8 s on: the fans at that end up (%.2f), the far end's not yet (%.2f)" % [r_near, r_far], true)
	_expect(_rise(crowd, 28.0, 5.0) > 0.2 and _rise(crowd, -28.0, 6.5) < 0.05, "the ripple reaches the far end, then they sit back over 3 s",
			true)
	crowd.react("fall", 1, 1.0)
	var o1: Vector3 = crowd.param(&"ripple_origin")
	_expect(o1.is_equal_approx(crowd.to_global(Vector3(31.8, 0.0, 0.0))), "a fall at the +X end: from there (%s)" % str(o1), true)
	_expect(crowd.last_react.get("kind") == "fall" and int(crowd.last_react.get("side")) == 1, "told the end only: %s" % str(crowd.last_react),
			true)
	await _ticks(60 * 11)
	_expect(float(crowd.param(&"ripple_k")) == 0.0, "the ripple done and cleared", true)


func _beat(crowd: RingCrowd) -> void:
	var md := MusicDirector.new()
	md.name = "MusicDirector"
	root.add_child(md)
	await _ticks(2)
	md.start_ring(false)
	await _ticks(10)
	_expect(md.ring_playing(), "the ring score plays (for the beat)")
	crowd.react("sudden", -1, 1.0)
	await _ticks(90)
	_expect(float(crowd.param(&"stand")) > 0.99 and float(crowd.param(&"clap")) > 0.99,
			"sudden death: half up and clapping (stand %.2f, clap %.2f, share %.2f)" % [float(crowd.param(&"stand")),
			float(crowd.param(&"clap")), float(crowd.param(&"stand_share"))], true)
	var worst := 0.0
	for i in 20:
		await process_frame
		worst = maxf(worst, absf(float(crowd.param(&"beat")) - md.ring_beat()))
	_expect(worst < 0.15, "the clap keeps the score's beat (MusicDirector.ring_beat, off by %.3f beats at most)" % worst, true)
	crowd.react("calm", -1, 1.0)
	await _ticks(90)
	_expect(float(crowd.param(&"stand")) < 0.01 and float(crowd.param(&"clap")) < 0.01, "calm: sat down, hands still", true)
	crowd.react("last_life", -1, 1.0)
	await _ticks(60)
	_expect(float(crowd.param(&"stand")) > 0.5, "a last life: half of them up (%.2f)" % float(crowd.param(&"stand")), true)
	md.queue_free()


func _positions() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ring/ring_crowd.gd")
	for bad: String in ["global_position", "RingRules", "competitors", "RingMode", "player"]:
		_expect(not src.contains(bad), "RingCrowd reads no %s" % bad, true)
	var dr := FileAccess.get_file_as_string("res://scripts/ring/ring_dressing.gd")
	var a := dr.find("func react(")
	var body := dr.substr(a, dr.find("\nfunc ", a + 10) - a)
	_expect(a >= 0 and not body.contains("global_position") and not body.contains("RingRules"), "RingDressing.react reads no position", true)
	var lv := FileAccess.get_file_as_string("res://scripts/ring/ring_level.gd")
	var f := lv.find("func _follow(")
	var fb := lv.substr(f, lv.find("\nfunc _show_match", f) - f)
	_expect(f >= 0 and not fb.contains("global_position") and fb.contains("falls[-1]"),
			"RingLevel._follow tells the stands only the fall's end, from RingRules' record", true)
