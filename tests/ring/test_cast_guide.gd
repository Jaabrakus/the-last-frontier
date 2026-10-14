extends SceneTree
## The cast guides (CastGuide; the owner, 2026-10-13: "guide lines and guide cast on where it should be", "implement for mobile
## and non mobile"). In the ring (a practice, the standing dummy 10 m off, the crosshair kept on his chest), each skill held on
## the right button through PlayerControls while its guide is read:
##   shot     fire's Punch: a line from his hands ending within END_M of the dummy (it meets him), drawn while held only
##   lobbed   earth's Boulder: dashed, its first point at the stone held before him
##   wave     earth's Fissure: a lane its spec's width wide along his facing
##   circle   earth's Column: a ring of its radius
##   wall     fire's Fire Wall: a footprint its width long
##   cone     fire's Breath: a wedge
##   none     nothing while no skill locks; nothing for the jab; nothing with MatchSetup.cast_guides "off"; "touch" with no touch
##            layer up: nothing
##   Godot --headless --fixed-fps 60 --path . -s tests/ring/test_cast_guide.gd [-- el=fire|earth]   (fire's checks or earth's)
## The last line "CAST GUIDE PASSED (<n> checks)" or "CAST GUIDE FAILED (<f> of <n>)".

const OWN_CFG := "user://test_cast_guide.cfg"
const END_M := 0.9
var mode: RingMode
var p: FrontierPlayer
var c: SwayCaster
var guide: CastGuide
var checks := 0
var fails: Array[String] = []
var aiming := false
var el := "fire"


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("el="):
			el = a.get_slice("=", 1)
	GameSettings.path = OWN_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OWN_CFG))
	InputSetup.ensure()
	KitWords.ensure_guard_action()
	MatchSetup.reload_scheme()
	MatchSetup.set_controls("full")
	MatchSetup._scheme = "keys"
	MatchSetup._aim_help = "light"
	MatchSetup.incoming = true
	MatchSetup.kind = "practice"
	MatchSetup.dummy = "stand"
	MatchSetup.element = el
	MatchSetup.foes = ["earth" if el == "fire" else "fire"]
	MatchSetup.difficulty = "normal"
	MatchSetup.light = "noon"
	MatchSetup.speed = 1.0
	MatchSetup.fresh = true
	MatchSetup.my_pct = -1.0
	MatchSetup.foe_pct = -1.0
	RingRules.rule_set_override = "stock"
	RingReplay.force = "off"
	BendCombo.enabled = false
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("CAST GUIDE FAILED (watchdog)")
		quit(2))
	change_scene_to_file("res://scenes/ring.tscn")
	_run.call_deferred()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, seconds: float) -> bool:
	for i in int(ceil(seconds * Engine.physics_ticks_per_second)):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _run() -> void:
	for i in 1800:
		await process_frame
		mode = RingMode.find(self)
		if mode != null and mode.foe != null and mode.phase == "FIGHT" and not current_scene.get_meta("loading_hold", false):
			break
	if mode == null:
		print("CAST GUIDE FAILED (no ring)")
		quit(1)
		return
	p = mode.player
	root.size = Vector2i(1280, 720)
	await _ticks(2)
	p.ignore_mouse_capture = true
	p.controls = PlayerControls.new(false)
	c = SwayCaster.of(p)
	guide = p.get_node_or_null(^"CastGuide") as CastGuide
	_expect(guide != null and MatchSetup.cast_guides() == "always", "the local player has his guide, on (%s)" % MatchSetup.cast_guides())
	physics_frame.connect(_aim)
	await _stage(10.0)
	await _ticks(10)
	_expect(not guide.shown, "nothing drawn while no skill locks")

	if el == "fire":
		await _fire_checks()
	else:
		await _earth_checks()

	if fails.is_empty():
		print("CAST GUIDE PASSED (%d checks)" % checks)
		quit(0)
	else:
		print("CAST GUIDE FAILED (%d of %d)" % [fails.size(), checks])
		quit(1)


## Skill `id`/`md` readied on key `k` and held on the right button: what the guide drew once its lock is full (or `wait` s in),
## then let go. {shown, shape, n, p0, p1, end}.
func _held(id: String, md: String, k: int, wait := 0.0) -> Dictionary:
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 3.0)
	p.hotbar.ready_move(k, id, md)
	await _ticks(3)
	p.controls.set_held(&"aim", true)
	if id == "stone_form":
		await _until(func() -> bool: return FormEffects.raised_of(p) != null, 3.0)    # (its stone up before him)
		await _ticks(int(wait * 60.0) + 5)
	elif wait > 0.0:
		await _ticks(int(wait * 60.0))
	else:
		await _until(func() -> bool: return c.state in [SwayCaster.State.FULL, SwayCaster.State.HOLDING], 3.0)
	await _ticks(2)
	var th := FormEffects.raised_of(p)
	var out := {"shown": guide.shown, "shape": guide.shape, "n": guide.points.size(),
			"raised": th.stone.global_position if th != null and th.stone != null and is_instance_valid(th.stone) else Vector3.INF,
			"p0": guide.points[0] if guide.points.size() > 0 else Vector3.INF,
			"p1": guide.points[1] if guide.points.size() > 1 else Vector3.INF,
			"end": guide.points[guide.points.size() - 1] if guide.points.size() > 0 else Vector3.INF}
	p.controls.set_held(&"aim", false)
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 3.0)
	await _ticks(30)
	return out


func _stage(d: float) -> void:
	aiming = false
	var g := RingMoves.arena_geo(mode.ring)
	var xf: Transform3D = g.xf
	var y := mode.ring.deck_y()
	var ax := (xf.basis.x * Vector3(1, 0, 1)).normalized()
	var mid := Vector3(xf.origin.x, y, xf.origin.z)
	RingLevel.place(mode.foe, Transform3D(Basis.looking_at(-ax, Vector3.UP), mid + ax * d * 0.5))
	RingLevel.place(p, Transform3D(Basis.looking_at(ax, Vector3.UP), mid - ax * d * 0.5))
	mode.rules.reset_pct(mode.foe, 0.0)
	mode.make_whole(mode.foe)
	mode.make_whole(p)
	aiming = true
	await _until(func() -> bool: return p.is_on_floor() and mode.foe.is_on_floor(), 2.0)
	await _ticks(40)


func _aim() -> void:
	if aiming and p != null and is_instance_valid(mode.foe):
		var cam := p.camera
		var want := (NpcSenses.chest_of(mode.foe) - cam.global_position).normalized()
		var fwd := -cam.global_basis.z
		var dy := wrapf(atan2(-want.x, -want.z) - atan2(-fwd.x, -fwd.z), -PI, PI)
		var dp := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(fwd.y, -1.0, 1.0))
		p.yaw += dy
		p.pitch = clampf(p.pitch + dp, -deg_to_rad(p.pitch_limit_deg), deg_to_rad(p.pitch_limit_deg))


func _fire_checks() -> void:
	# ---- fire: the Punch's line, the Breath's wedge, the Fire Wall's footprint
	var got := await _held("fire_blast", "punch", 0)
	var chest := NpcSenses.chest_of(mode.foe)
	var end: Vector3 = got.end
	_expect(String(got.shape) == "shot" and end.distance_to(chest) <= END_M,
			"the Punch held: a line ending on him (%s, %.2f m from his chest)" % [got.shape, end.distance_to(chest)])
	await _ticks(20)
	_expect(not guide.shown, "let go: the guide goes")
	got = await _held("fire_breath", "breath", 3)
	_expect(String(got.shape) == "cone" and int(got.n) >= 3, "the Breath held: a wedge on the deck (%s)" % got.shape)
	got = await _held("fire_wall", "wall", 3)
	var w0: Vector3 = got.p0
	var w1: Vector3 = got.p1
	var fw_w := float((SwayMoves.move("fire_wall").bend.wall as Dictionary).get("width_m", 4.0))
	_expect(String(got.shape) == "wall" and absf(w0.distance_to(w1) - fw_w) < 0.05,
			"the Fire Wall held: its footprint %.1f m long (%s)" % [w0.distance_to(w1), got.shape])
	# ---- the jab draws nothing
	p.controls.set_held(&"fire", true)
	await _until(func() -> bool: return c.state != SwayCaster.State.IDLE, 1.0)
	await _ticks(2)
	_expect(not guide.shown, "the jab locking draws nothing")
	p.controls.set_held(&"fire", false)
	await _until(func() -> bool: return c.state == SwayCaster.State.IDLE, 2.0)
	# ---- off, and touch only with no touch layer
	MatchSetup.set_cast_guides("off")
	got = await _held("fire_blast", "punch", 0)
	_expect(not bool(got.shown), "cast guides Off: nothing drawn")
	MatchSetup.set_cast_guides("touch")
	got = await _held("fire_blast", "punch", 0)
	_expect(not bool(got.shown), "cast guides Touch only, no touch layer up: nothing drawn")
	MatchSetup.set_cast_guides("always")



func _earth_checks() -> void:
	# ---- earth: the Boulder's dashed arc, the Fissure's lane, the Column's ring
	var got := await _held("stone_form", "cannonball", 0, 0.1)
	var p0: Vector3 = got.p0
	var st: Vector3 = got.raised
	_expect(String(got.shape) == "lobbed" and st != Vector3.INF and p0.distance_to(st) < 0.3,
			"the Boulder held: a dashed arc from the stone before him (%s, %.2f m)" % [got.shape,
			p0.distance_to(st) if st != Vector3.INF else -1.0])
	got = await _held("earth_shove", "push", 1)
	var lw: float = (got.p0 as Vector3).distance_to(got.p1)
	var fz := float((SwayMoves.move("earth_shove").bend.push as Dictionary).get("width_m", 2.4))
	_expect(String(got.shape) == "wave" and absf(lw - fz) < 0.05, "the Fissure held: a lane %.1f m wide (%s)" % [lw, got.shape])
	got = await _held("earth_shove", "column", 1)
	_expect(String(got.shape) == "circle" and int(got.n) >= 16, "the Column held: a ring where it rises (%s)" % got.shape)

