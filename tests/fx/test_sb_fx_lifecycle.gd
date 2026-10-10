extends SceneTree
## Everything the Spellbreak bridge plays ENDS (SbFx, scripts/fx/cascade/sb_fx.gd; data/bending/sb_fx), headless
## (SbFx.allow_headless: the Cascade runtime simulates without a window). Every element is forced on (the owner switched them
## all off on 2026-10-09; the bridge's own logic is tested whatever config.json says).
##   ends      every entry of the four tables, played the way its seam plays it (the roles a caller holds through
##             SbFx.start() are stopped, a caster's node freed, 1 s in; the others go through fire() with a node that is freed
##             the same way, as a bolt or a zone is), has no effect left playing once its tail is out
##   net       a play nobody holds, that follows no node and travels nowhere, of an effect that loops for ever (water_redirect's
##             swing: CB_RiversReflection_FxP) is stopped after SbFx.MAX_LIFE_S, and config.json's max_life_s overrides it (0:
##             no net); a held play, a followed one, one with a life of its own and one that travels are left alone
##   cap       39 more swings leave the max_playing room it needs: nothing is still counted a few seconds after them
## Last line "SB FX LIFECYCLE PASSED (n checks)" or "SB FX LIFECYCLE FAILED"; exit 0 only on a pass; a watchdog quits with 2.
##   Godot --headless --fixed-fps 60 --path . -s tests/fx/test_sb_fx_lifecycle.gd

const NAME := "SB FX LIFECYCLE"
const WATCHDOG_S := 540.0
## Roles the game plays through SbFx.start() / sustain() and ends with stop() (grep SbFx.start in scripts/).
const HELD := ["zone", "stand", "hang", "flight", "return_flight", "held", "charge", "grow", "idle", "ride", "dash_trail",
		"dash_flames", "charged", "roll", "air_trail"]
## Effects played at once (below config.json's max_playing, so none is refused).
const BATCH := 24
const LET_GO_FRAME := 60
## Longest a batch is followed: the net (MAX_LIFE_S) plus the longest tail (SpellFx.MAX_TAIL_S) plus the let-go.
const RUN_FRAMES := 60 * 20
const SWING := ["water", "water_redirect/redirect", "swing"]

var checks := 0
var fails: Array[String] = []
var stage: Node3D
var bodies := {}
var player: SpellFx


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		print("%s FAILED (watchdog)" % NAME)
		quit(2))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _body(el: String, at: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.name = "Caster_" + el
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	cs.position = Vector3.UP * 0.9
	b.add_child(cs)
	stage.add_child(b)
	b.global_position = at
	Bending.of(b).element = el
	return b


func _end() -> void:
	SbFx.allow_headless = false
	SbFx.force_on = null
	SbFx.force_elements = {}
	SbFx.reload_data()
	if fails.is_empty() and checks > 0:
		print("%s PASSED (%d checks)" % [NAME, checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d)" % [NAME, fails.size(), checks])
		quit(1)


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	ground.add_child(cs)
	stage.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	var i := 0
	for el in SbFx.ELEMENTS:
		bodies[el] = _body(el, Vector3(float(i) * 3.0, 0, 0))
		i += 1
	await _frames(2)
	player = SpellFx.of(stage)
	await _frames(1)
	await _net()
	await _ends()
	_end()


# ---------------------------------------------------------------- the net
func _swing_ctx(x := 0.0) -> Dictionary:
	return {"at": Vector3(x, 1, -4), "dir": Vector3.FORWARD, "el": "water"}


func _net() -> void:
	var sw := SbFx.entry(SWING[0], SWING[1], SWING[2])
	_expect(not sw.is_empty() and SpellFx.has_effect(String(sw.effect)), "the swing entry exists (%s)" % String(sw.get("effect", "")).get_file())
	var spec_endless := false
	for em: Dictionary in SpellFx.spec(String(sw.effect)).get("emitters", []):
		if bool(em.get("enabled", false)) and CascadeFx.loops_forever(em):
			spec_endless = true
	_expect(spec_endless, "its effect has an emitter that loops for ever (the case the net is for)")
	_expect(SbFx._endless(sw), "SbFx._endless sees that")
	# played through fire(): nothing holds it, it follows nothing
	var r := SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx())
	var h: SpellFx.Handle = r.handles[0] if not r.handles.is_empty() else null
	_expect(h != null and is_equal_approx(h.life, SbFx.MAX_LIFE_S), "an unheld, unfollowing play of it gets a life of MAX_LIFE_S (%s s)" % [h.life if h != null else -1.0])
	var f := 0
	while h != null and h.is_playing() and f < 60 * 20:
		await process_frame
		f += 1
	_expect(h != null and not h.is_playing() and f > int(SbFx.MAX_LIFE_S * 60.0) - 6,
			"it stops at about MAX_LIFE_S and plays out (%.1f s)" % [f / 60.0])
	# held through start(): left to its owner
	var owner := Node3D.new()
	stage.add_child(owner)
	var held := SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx(), true)
	var hh: SpellFx.Handle = held.handles[0] if not held.handles.is_empty() else null
	_expect(hh != null and hh.life == 0.0, "a held play keeps no life of the net's (the owner stops it)")
	if hh != null:
		hh.kill()
	# a life of its own is kept
	var own := SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx().merged({"life": 1.5}))
	_expect(not own.handles.is_empty() and is_equal_approx((own.handles[0] as SpellFx.Handle).life, 1.5), "a life from the caller is kept")
	for x: SpellFx.Handle in own.handles:
		x.kill()
	# one that follows a node is left to that node
	var node := Node3D.new()
	stage.add_child(node)
	node.global_position = Vector3(0, 1, -4)
	var fol := SbFx._play(bodies.fire, "fire_blast/punch.grown", "flight", {"node": node, "dir": Vector3.FORWARD})
	var fh: SpellFx.Handle = fol.handles[0] if not fol.handles.is_empty() else null
	_expect(fh != null and fh.life == 0.0 and fh.following, "a play that follows a node keeps no life of the net's (it ends with the node)")
	if fh != null:
		fh.kill()
	node.queue_free()
	# config.json's max_life_s overrides it; 0 switches the net off
	SbFx.config()["max_life_s"] = 1.0
	var r1 := SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx())
	_expect(not r1.handles.is_empty() and is_equal_approx((r1.handles[0] as SpellFx.Handle).life, 1.0), "max_life_s in config.json sets the net's length")
	for x: SpellFx.Handle in r1.handles:
		x.kill()
	SbFx.config()["max_life_s"] = 0.0
	var r0 := SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx())
	_expect(not r0.handles.is_empty() and (r0.handles[0] as SpellFx.Handle).life == 0.0, "max_life_s 0 switches the net off")
	for x: SpellFx.Handle in r0.handles:
		x.kill()
	SbFx.reload_data()
	owner.queue_free()
	# a fight's worth of swings: nothing still counted a few seconds after the last
	for k in 39:
		SbFx._play(bodies.water, SWING[1], SWING[2], _swing_ctx(float(k) * 0.1))
	_expect(player.playing_count() >= 30, "39 swings are playing (%d)" % player.playing_count())
	await _frames(int(60.0 * (SbFx.MAX_LIFE_S + 0.5)))
	var left := 0
	for k in 60 * 12:
		if player.playing_count() == 0:
			break
		await process_frame
		left += 1
	_expect(player.playing_count() == 0, "they are all gone (%d playing; %.1f s after the net's end)" % [player.playing_count(), left / 60.0])
	_expect(SbFx.fire(bodies.fire, "fire_blast/punch", "impact", {"at": Vector3(0, 1, -3), "dir": Vector3.FORWARD, "info": {}}),
			"so a fire punch's impact is no longer refused for the cap")
	player.kill_all()
	await _frames(2)


# ---------------------------------------------------------------- every entry ends
func _ends() -> void:
	var todo: Array = []
	for el: String in SbFx.ELEMENTS:
		var t := SbFx.table(el)
		for key: String in t:
			for role: String in t[key]:
				if (t[key][role] is Dictionary) and not String(role).begins_with("_"):
					todo.append([el, key, role])
	var never: Array = []
	var b0 := 0
	while b0 < todo.size():
		var batch := todo.slice(b0, b0 + BATCH)
		b0 += BATCH
		var recs: Array = []
		for k in batch.size():
			var el: String = batch[k][0]
			var key: String = batch[k][1]
			var role: String = batch[k][2]
			var pos := Vector3(float(k % 8) * 2.0 - 7.0, 0.0, -float(k / 8) * 3.0 - 3.0)
			var node := Node3D.new()
			stage.add_child(node)
			node.global_position = pos
			var ctx := {"node": node, "at": pos + Vector3.UP * 0.2, "dir": Vector3.FORWARD, "to": pos + Vector3.FORWARD * 6.0,
					"size": Vector3(4, 2, 0.5), "radius": 2.0, "normal": Vector3.UP, "el": el}
			var held := role in HELD
			var handles: Array = []
			if held:
				SbFx.start(node, "s", bodies[el], key, role, ctx)
				for h in (SbFx._held.get(node.get_instance_id(), {}) as Dictionary).get("s", []):
					if h is SpellFx.Handle:
						handles.append(h)
			else:
				handles = SbFx._play(bodies[el], key, role, ctx).handles
			recs.append({"el": el, "key": key, "role": role, "held": held, "handles": handles, "node": node,
					"effect": String(SbFx.entry(el, key, role).get("effect", ""))})
		for f in RUN_FRAMES:
			await process_frame
			if f == LET_GO_FRAME:
				for r in recs:
					if r.held:
						SbFx.stop(r.node, "s")
					if is_instance_valid(r.node):
						(r.node as Node).queue_free()
			if f > LET_GO_FRAME and f % 30 == 0 and recs.all(func(r: Dictionary) -> bool:
					return (r.handles as Array).all(func(h: SpellFx.Handle) -> bool: return not h.is_playing())):
				break
		for r in recs:
			var alive := 0
			for h: SpellFx.Handle in r.handles:
				if h.is_playing():
					alive += 1
			if alive > 0:
				never.append("%s %s %s (%s)" % [r.el, r.key, r.role, String(r.effect).get_file()])
		player.kill_all()
		await _frames(1)
	for n in never.slice(0, 12):
		print("    never ended: " + n)
	_expect(todo.size() >= 140, "every entry of the four tables was played (%d)" % todo.size())
	_expect(never.is_empty(), "every one ended once its seam let go (%d of %d never did)" % [never.size(), todo.size()])
