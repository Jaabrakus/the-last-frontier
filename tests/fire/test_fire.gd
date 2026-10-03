extends SceneTree
## Fire and ruin (scripts/fire: FireSpread, FireFx, FireRuin, FireTorch) on the real level, survival on:
##   Godot --headless --fixed-fps 60 --path . -s tests/fire/test_fire.gd -- survival=on
##   api      the level installs the fire (installing again gives the same one); a stone piece, the player and a plain
##            node do not burn; the charred shader compiles (its `dim` is listed)
##   spread   three walls in a line east of the fort: the first set alight catches (catching, then burning), the one
##            touching it catches from it, the one 12 m off takes no heat at all; the first turns charred, burns through
##            and falls to a ruin (charred stubs, a scorched patch), the count goes up; the second falls after it and
##            the far one still stands
##   fall     a gable resting on a wall falls within FALL_S of the wall, leaving no stub (all of it was high)
##   gone     a burning wall taken down by another machine ("unbuild") leaves its ruin here too and its gable falls;
##            one only catching leaves nothing
##   wind     downwind catches first and faster than with no wind, upwind not by then; spread_rate's own numbers
##   rain     the same pair in rain (a node of the weather group TorchState reads): it catches slower, the neighbour
##            much later
##   torch    a lit torch held against a wall, the player standing there 6 s: nothing (only on purpose); the crosshair
##            on it offers "Set the notched log wall alight", E holds the torch there and it catches after TORCH_S; E
##            again stops it, putting the torch away stops it; a wall still catching offers "Beat out the flames" and
##            E puts it out; a wall alight all over offers nothing
##   burnable a node tagged burnable (a story's cabin) catches, sets the wall beside it alight and burns down where it
##            stands (charred, its colliders off, kept by its path)
##   contents a cradle alight is out of the cradles group (no place for the baby), back in when put out; a chest alight
##            with things in it tells the player; a woodpile's logs char with it
##   ruins    a wall rebuilt on a ruin clears it, the ruin of the wall touching its end stays; the stubs stand RUIN_H
##            over the ground at both ends (the cut follows the slope); Take down in build mode clears a ruin
##   takedown a burning wall pulled down in build mode gives nothing back
##   area     ignite_area sets 20 pieces alight; the fire's tick with them all burning, against the 1 ms budget, and on
##            through their charring and their falls: never more than FALLS_PER_TICK in a tick, spread over many ticks
##   save     the fire part through JSON: the ruins, the pieces alight (their stage) and the count come back; a story's
##            burnable not in the level yet is waited for and taken up when it comes; the join snapshot has the part
## The fire is stepped by hand (FireSpread.manual) in TICK_S steps, so its minutes pass in a few frames.
## Ends with "FIRE TEST PASSED (<n> checks)" or "FIRE TEST FAILED (<f> of <n>)".

const G := preload("res://scripts/building/build_geometry.gd")

var checks := 0
var fails: Array[String] = []
var report := {}
var fire: FireSpread
var world: BuildWorld
var player: FrontierPlayer


func _expect(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _hz() -> float:
	return float(Engine.physics_ticks_per_second)


## A piece of `type` standing on the ground at (x, z), turned `yaw`.
func _piece(type: String, x: float, z: float, yaw := 0.0) -> BuiltPiece:
	var xf := FortPlan.settle(type, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, z))) if type in ["palisade", "palisade_gate"] \
			else Transform3D(Basis(Vector3.UP, yaw), Vector3(x, FrontierTerrain.height_at(x, z), z))
	return world.add_piece(type, xf, true, -1, FortPlan.stake_ground(type, xf))


## Whether `p` (a node, or its instance id: a lambda keeps the id, not the node it would find freed) is gone.
func _gone(p: Variant) -> bool:
	var o: Variant = instance_from_id(p) if p is int else p
	return not is_instance_valid(o) or (o as Node).is_queued_for_deletion() or not (o as Node).is_inside_tree()


func _burn(p: Node) -> FireSpread.Burn:
	return fire._burns.get(p.get_instance_id()) as FireSpread.Burn if is_instance_valid(p) else null


## Steps the fire TICK_S at a time until `cond` holds (the fire's seconds it took) or `max_s` pass (-1).
func _until(cond: Callable, max_s: float) -> float:
	var t := 0.0
	var n := 0
	while t < max_s:
		fire.step(FireSpread.TICK_S)
		t += FireSpread.TICK_S
		n += 1
		if n % 8 == 0:
			await process_frame
		if cond.call():
			return t
	return -1.0


func _for(secs: float) -> void:
	await _until(func() -> bool: return false, secs)


func _ruin_of(type: String) -> FireRuin:
	for r in fire.ruins:
		if is_instance_valid(r) and String(r.data.get("type", "")) == type:
			return r
	return null


func _ruin_at(x: float, z: float) -> FireRuin:
	for r in fire.ruins:
		if is_instance_valid(r) and not r.is_queued_for_deletion() and Vector2(r.global_position.x - x, r.global_position.z - z).length() < 0.2:
			return r
	return null


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(25)
	paused = false
	player = current_scene.get_node_or_null("Player") as FrontierPlayer
	fire = FireSpread.find(self)
	world = BuildWorld.of(self)
	_expect(player != null and world != null, "the level has the player and the building")
	_expect(fire != null and fire.get_parent() == current_scene, "the level installs the fire (FireSpread, found by its group)")
	if fire == null or world == null:
		_end()
		return
	player.ignore_mouse_capture = true
	fire.manual = true
	fire.rain_override = 0.0
	fire.wind_override = Vector3.ZERO
	await _test_api()
	await _test_spread()
	await _test_fall()
	await _test_gone()
	await _test_wind()
	await _test_rain()
	await _test_torch()
	await _test_burnable()
	await _test_contents()
	await _test_ruins()
	await _test_take_down()
	await _test_area()
	await _test_save()
	_end()


# --- What burns ------------------------------------------------------------------------------------------------

func _test_api() -> void:
	_expect(FireSpread.install(current_scene) == fire and get_nodes_in_group(FireSpread.GROUP).size() == 1,
			"installing the fire again gives the same one (no second FireSpread)")
	var names: Array = FireRuin.material().shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return String(u.name))
	_expect(names.has("dim"), "the charred shader compiles (its uniforms: %s)" % [names])
	_expect(not fire.ignite(player) and not fire.is_burning(player), "the player does not burn")
	var plain := Node3D.new()
	current_scene.add_child(plain)
	_expect(not fire.ignite(plain), "nor a plain node that is not tagged burnable")
	plain.queue_free()


# --- Spread, burn through, ruin ------------------------------------------------------------------------------

func _test_spread() -> void:
	var stone := _piece("hearth", 40.0, 70.0)
	_expect(not fire.ignite(stone) and not fire.is_burning(stone), "a stone hearth does not burn")
	var a := _piece("wall", 21.0, 6.0)
	var b := _piece("wall", 24.0, 6.0)
	var c := _piece("wall", 36.0, 6.0)
	var a_id := a.piece_id
	var b_id := b.piece_id
	await _frames(2)
	_expect(FireSpread.box_gap(fire._box_of(a), fire._box_of(b)) < 0.05 and FireSpread.box_gap(fire._box_of(b), fire._box_of(c)) > 8.0,
			"the walls' boxes: the second touches the first, the third is %.1f m off the second" % FireSpread.box_gap(fire._box_of(b), fire._box_of(c)))
	_expect(fire.ignite(a.body), "a wall set alight (through its collider's body) catches")
	_expect(not fire.ignite(a), "a wall alight does not catch again")
	_expect(fire.is_burning(a) and fire.stage_of(a) == "catching" and fire.burning_count() == 1, "it is catching (%s)" % fire.stage_of(a))
	_expect(fire.is_burning(a.global_position + Vector3(0, 1.2, 0)) and not fire.is_burning(c.global_position + Vector3(0, 1.2, 0)),
			"a point in it is in the fire, a point in the far wall is not")
	var cs := _burn(a).catch_s
	_expect(absf(cs / FireSpread.CATCH_S - 1.0) <= FireSpread.PACE + 0.001, "it catches at its own pace (%.2f s)" % cs)
	await _for(cs + 0.5)
	_expect(fire.stage_of(a) == "burning", "after %.1f s it burns all over (%s)" % [cs, fire.stage_of(a)])
	var tb := await _until(func() -> bool: return fire.is_burning(b), 60.0)
	tb += cs + 0.5
	report["dry_catch_s"] = tb
	_expect(tb > FireSpread.CATCH_S and tb < 40.0, "the touching wall catches from it %.1f s after it was lit" % tb)
	_expect(not fire.is_burning(c) and fire.heat_of(c) == 0.0, "the wall 12 m off takes no heat")
	await _until(func() -> bool: return fire.stage_of(a) == "charred", 60.0)
	var gis: Array = a.highlight_targets()
	_expect(fire.stage_of(a) == "charred" and not gis.is_empty() and (gis[0] as GeometryInstance3D).material_override == FireRuin.material(),
			"part way through it turns to charred wood (the material swap)")
	var ai := a.get_instance_id()
	var fell := await _until(func() -> bool: return _gone(ai), 120.0)
	await _frames(2)
	_expect(fell > 0.0, "it burns through and falls (%.0f s on)" % fell)
	_expect(world.by_id(a_id) == null and fire.burned_count() == 1, "it is taken down and counted (%d burnt)" % fire.burned_count())
	var r := _ruin_of("wall")
	_expect(r != null and fire.ruins.size() == 1, "it leaves a ruin (%d)" % fire.ruins.size())
	if r:
		var meshes := r.find_children("*", "GeometryInstance3D", true, false)
		_expect(not meshes.is_empty() and (meshes[0] as GeometryInstance3D).material_override == FireRuin.material(),
				"the ruin is the wall's own look in charred wood (%d meshes)" % meshes.size())
		var ground := FrontierTerrain.height_at(21.0, 6.0)
		_expect(absf(float(r.data.cut) - ground - float(FireRuin.RUIN_H.wall)) < 0.01, "cut off %.2f m over the ground" % (float(r.data.cut) - ground))
		_expect(r.get_node_or_null("Scorch") is Decal, "with a scorched patch of ground under it")
		_expect(r.find_children("*", "CollisionShape3D", true, false).is_empty(), "and no colliders: the way through is open")
	var bi := b.get_instance_id()
	var fell_b := await _until(func() -> bool: return _gone(bi), 150.0)
	await _frames(2)
	_expect(fell_b > 0.0 and world.by_id(b_id) == null and fire.burned_count() == 2, "the second wall burns through after it (%d burnt)" % fire.burned_count())
	_expect(is_instance_valid(c) and world.by_id(c.piece_id) == c and not fire.is_burning(c), "the far wall still stands, never alight")


# --- What rests on it falls with it ------------------------------------------------------------------------

func _test_fall() -> void:
	var w1 := _piece("wall", 21.0, 90.0)
	var gab := world.add_piece("gable", w1.global_transform * Transform3D(Basis(), Vector3(0, G.WALL_H, 0)), false, w1.piece_id)
	await _frames(2)
	_expect(world.dependents(w1).has(gab), "the gable rests on the wall")
	fire.ignite(w1)
	await _for(_burn(w1).catch_s + 1.0)
	_expect(not fire.is_burning(gab) or fire.stage_of(gab) == "catching", "the gable over it heats (%.2f)" % fire.heat_of(gab))
	_burn(w1).left = 0.2      # (the wall at the end of its burning)
	var wi := w1.get_instance_id()
	var gi := gab.get_instance_id()
	var t := await _until(func() -> bool: return _gone(wi), 5.0)
	_expect(t > 0.0, "the wall falls")
	var tg := await _until(func() -> bool: return _gone(gi), FireSpread.FALL_S + 1.0)
	await _frames(2)
	_expect(tg > 0.0 and tg <= FireSpread.FALL_S + 0.5, "the gable on it falls %.2f s after" % tg)
	var rg := _ruin_of("gable")
	_expect(rg != null and rg.find_children("*", "GeometryInstance3D", true, false).is_empty() and rg.get_node_or_null("Scorch") is Decal,
			"a gable leaves no stub (all of it was high), only the scorch")


# --- Taken down by another machine (co-op: its fire got there first) ----------------------------------------

func _test_gone() -> void:
	var w1 := _piece("wall", 21.0, 170.0)
	var gab := world.add_piece("gable", w1.global_transform * Transform3D(Basis(), Vector3(0, G.WALL_H, 0)), false, w1.piece_id)
	await _frames(2)
	fire.ignite(w1)
	await _for(_burn(w1).catch_s + 1.0)
	var n0 := fire.ruins.size()
	var c0 := fire.burned_count()
	world.remove_piece(w1)            # (as NetSession's "unbuild" does)
	await _frames(2)
	_expect(fire.ruins.size() == n0 + 1 and fire.burned_count() == c0 + 1 and _ruin_at(21.0, 170.0) != null,
			"a burning wall taken down by another machine leaves its ruin here too (%d ruins, %d burnt)" % [fire.ruins.size(), fire.burned_count()])
	var gi := gab.get_instance_id()
	var tg := await _until(func() -> bool: return _gone(gi), FireSpread.FALL_S + 1.0)
	await _frames(2)
	_expect(tg > 0.0, "and the gable resting on it burns and falls after it (%.2f s)" % tg)
	var w2 := _piece("wall", 30.0, 170.0)
	await _frames(1)
	fire.ignite(w2)
	var n1 := fire.ruins.size()
	world.remove_piece(w2)
	await _frames(2)
	_expect(fire.ruins.size() == n1 and fire.burning_count() == 0, "one only catching, taken down, leaves nothing (%d alight)" % fire.burning_count())


# --- Wind ----------------------------------------------------------------------------------------------------

func _test_wind() -> void:
	var box := AABB(Vector3(-1.5, 0, -0.15), Vector3(3, 2.7, 0.3))
	var east := AABB(Vector3(1.5, 0, -0.15), Vector3(3, 2.7, 0.3))
	var west := AABB(Vector3(-4.5, 0, -0.15), Vector3(3, 2.7, 0.3))
	var gale := Vector3(1, 0, 0)
	var calm := FireSpread.spread_rate(box, east, 1.0, Vector3.ZERO, 0.0)
	var down := FireSpread.spread_rate(box, east, 1.0, gale, 0.0)
	var up := FireSpread.spread_rate(box, west, 1.0, gale, 0.0)
	report["rate_calm_down_up"] = [calm, down, up]
	_expect(down > calm * 2.0 and up < calm * 0.5, "spread_rate: downwind %.3f, calm %.3f, upwind %.3f a second" % [down, calm, up])
	var far := AABB(Vector3(4.4, 0, -0.15), Vector3(3, 2.7, 0.3))
	_expect(FireSpread.spread_rate(box, far, 1.0, Vector3.ZERO, 0.0) == 0.0 and FireSpread.spread_rate(box, far, 1.0, gale, 0.0) > 0.0,
			"a box 2.9 m off: out of reach in calm air, within it downwind")
	fire.wind_override = gale
	var f0 := _piece("wall", 21.0, 50.0)
	var dn := _piece("wall", 24.0, 50.0)
	var uw := _piece("wall", 18.0, 50.0)
	await _frames(2)
	fire.ignite(f0)
	var t := await _until(func() -> bool: return fire.is_burning(dn), 60.0)
	report["downwind_catch_s"] = t
	_expect(t > 0.0 and t < float(report.get("dry_catch_s", 99.0)), "with the wind toward it the downwind wall catches in %.1f s (calm: %.1f s)" % [t, float(report.get("dry_catch_s", -1.0))])
	_expect(not fire.is_burning(uw), "the upwind wall has not caught by then (heat %.2f)" % fire.heat_of(uw))
	fire.wind_override = Vector3.ZERO


# --- Rain ----------------------------------------------------------------------------------------------------

func _test_rain() -> void:
	var dry := FireSpread.spread_rate(AABB(Vector3.ZERO, Vector3.ONE), AABB(Vector3(1, 0, 0), Vector3.ONE), 1.0, Vector3.ZERO, 0.0)
	var wet := FireSpread.spread_rate(AABB(Vector3.ZERO, Vector3.ONE), AABB(Vector3(1, 0, 0), Vector3.ONE), 1.0, Vector3.ZERO, 0.9)
	_expect(wet < dry * 0.5, "spread_rate in heavy rain: %.3f against %.3f dry" % [wet, dry])
	# the weather's rain, as the torches read it (a node of the weather group with a `rain`)
	var s := GDScript.new()
	s.source_code = "extends Node\nvar rain := 0.9\n"
	s.reload()
	var wx := Node.new()
	wx.set_script(s)
	wx.name = "TestRain"
	wx.add_to_group(TorchState.WEATHER_GROUP)
	current_scene.add_child(wx)
	fire.rain_override = -1.0
	var d := _piece("wall", 21.0, 30.0)
	var e := _piece("wall", 24.0, 30.0)
	await _frames(2)
	_expect(fire.rain_at(d.global_position) >= 0.9, "the fire reads the weather's rain (%.2f)" % fire.rain_at(d.global_position))
	fire.ignite(d)
	var cs := _burn(d).catch_s
	await _for(cs + 0.5)
	_expect(fire.stage_of(d) == "catching", "in rain it is still catching after %.1f s" % cs)
	var t := await _until(func() -> bool: return fire.is_burning(e), 150.0)
	if t > 0.0:
		t += cs + 0.5
	report["rain_catch_s"] = t
	var dry_t := float(report.get("dry_catch_s", 99.0))
	_expect(t < 0.0 or t > dry_t * 1.6, "rain slows it: the neighbour catches after %.1f s (dry: %.1f s)" % [t, dry_t])
	wx.queue_free()
	fire.rain_override = 0.0


# --- The torch: on purpose, with E ---------------------------------------------------------------------------

## Physics frames (at most `max_s` s of them) until `cond` holds: the seconds (-1: never).
func _phys_until(cond: Callable, max_s: float) -> float:
	var n := 0
	while n < int(max_s * _hz()):
		if cond.call():
			return n / _hz()
		await physics_frame
		n += 1
	return n / _hz() if cond.call() else -1.0


func _test_torch() -> void:
	if player.torch == null or not player.torch.take_out(true):
		_expect(false, "the player takes out a lit torch")
		return
	await _physics(40)
	var flame := player.torch.flame_position()
	var out := flame - player.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else Vector3.FORWARD
	var at := flame + out * 0.05
	var yaw := atan2(out.x, out.z)
	var pw := world.add_piece("wall", Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)), true, -1)
	var back := player.global_position - out * 0.6
	var pw2 := world.add_piece("wall", Transform3D(Basis(Vector3.UP, yaw), Vector3(back.x, FrontierTerrain.height_at(back.x, back.z), back.z)), true, -1)
	await _physics(2)
	# the old way of it: the flame on the wood, the player only standing there
	_expect(fire.burnable_at(flame) == pw, "the lit torch's flame is right on the wall the player stands against")
	await _physics(int(6.0 * _hz()))
	_expect(not fire.is_burning(pw), "standing there 6 s with the lit torch sets nothing alight (only E does)")
	# the crosshair on it: E sets it alight
	fire.torch.aim_at = at
	await _physics(int(0.6 * _hz()))
	var off: Node = fire.torch.offer
	_expect(off != null and off.is_in_group(PlacedWeapon.GROUP) and String(off.interact_prompt(player)) == "Set the notched log wall alight",
			"the crosshair on it with a lit torch: E offers to set it alight (%s)" % (off.interact_prompt(player) if off else "no offer"))
	_expect(off != null and not (off.highlight_targets() as Array).is_empty() and (off.highlight_targets() as Array)[0] == pw.highlight_targets()[0],
			"and the wall is what glows")
	if off == null:
		return
	off.interact(player)                       # (the interactor's tap: PlayerInteractor._act)
	await _physics(int(1.0 * _hz()))
	_expect(fire.torch.offer != null and String(fire.torch.offer.interact_prompt(player)).begins_with("Stop holding the torch"),
			"while it is held there E stops it (%s)" % (fire.torch.offer.interact_prompt(player) if fire.torch.offer else "no offer"))
	var secs := 1.0 + await _phys_until(func() -> bool: return fire.is_burning(pw), 6.0)
	report["torch_s"] = secs
	_expect(fire.is_burning(pw) and secs >= FireSpread.TORCH_S - FireSpread.TORCH_POLL and secs <= FireSpread.TORCH_S + 2.0 * FireSpread.TORCH_POLL,
			"held to it with E, the wall catches after %.2f s" % secs)
	# stopped with E, or the torch put away: nothing
	fire.torch.aim_at = back + Vector3(0, 1.3, 0)
	await _physics(int(0.6 * _hz()))
	off = fire.torch.offer
	_expect(off != null and String(off.interact_prompt(player)) == "Set the notched log wall alight", "the wall behind: offered too")
	if off:
		off.interact(player)
		await _physics(int(1.0 * _hz()))
		fire.torch.offer.interact(player)       # (E again)
		await _physics(int(4.0 * _hz()))
		_expect(not fire.is_burning(pw2) and fire.torch.job.is_empty(), "E again takes the torch away: it does not catch")
		fire.torch.offer.interact(player)
		await _physics(int(1.0 * _hz()))
		player.torch.put_away()
		await _physics(int(4.0 * _hz()))
		_expect(not fire.is_burning(pw2) and fire.torch.job.is_empty(), "the torch put away part way: it does not catch")
	# a fire still catching is beaten out
	fire.torch.aim_at = at
	await _physics(int(0.6 * _hz()))
	off = fire.torch.offer
	_expect(fire.stage_of(pw) == "catching" and off != null and String(off.interact_prompt(player)) == "Beat out the flames on the notched log wall",
			"a wall catching: E offers to beat out the flames (%s)" % (off.interact_prompt(player) if off else "no offer"))
	if off:
		off.interact(player)
		var bs := await _phys_until(func() -> bool: return not fire.is_burning(pw), 5.0)
		_expect(bs > 0.0 and absf(bs - FireTorch.BEAT_S) <= 2.0 * FireSpread.TORCH_POLL and fire.heat_of(pw) == 0.0,
				"beaten at for %.2f s, it is out" % bs)
	# alight all over: nothing to do by hand
	fire.ignite(pw)
	await _for(_burn(pw).catch_s + 0.5)
	await _physics(int(0.6 * _hz()))
	_expect(fire.stage_of(pw) == "burning" and fire.torch.offer == null, "a wall alight all over: no offer (it cannot be beaten out)")
	fire.put_out(pw, true)
	fire.torch.aim_at = Vector3.INF
	await _physics(int(0.6 * _hz()))


# --- A burnable that is not a built piece (a story's cabin) --------------------------------------------------

func _hut(nm: String, at: Vector3, add := true) -> Node3D:
	var hut := Node3D.new()
	hut.name = nm
	hut.add_to_group(FireSpread.BURNABLE_GROUP)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 3, 4)
	mi.mesh = bm
	mi.position.y = 1.5
	hut.add_child(mi)
	var sb := StaticBody3D.new()
	sb.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 3, 4)
	cs.shape = bs
	cs.position.y = 1.5
	sb.add_child(cs)
	hut.add_child(sb)
	if add:
		current_scene.add_child(hut)
		hut.global_position = at
	else:
		hut.position = at
	return hut


func _test_burnable() -> void:
	var at := Vector3(40.0, 0.0, 150.0)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var hut := _hut("TestHut", at)
	var mi := hut.get_node("Mesh") as MeshInstance3D
	var sb := hut.get_node("Body") as StaticBody3D
	var cs := sb.get_node("Shape") as CollisionShape3D
	var nextdoor := _piece("wall", at.x + 3.6, at.z)
	await _physics(2)
	_expect(fire.ignite(sb) and fire.is_burning(hut), "a node tagged burnable catches (set alight through its collider)")
	var t := await _until(func() -> bool: return fire.is_burning(nextdoor), 60.0)
	_expect(t > 0.0, "and sets the built wall beside it alight (%.1f s)" % t)
	var fell := await _until(func() -> bool: return not fire.is_burning(hut), 120.0)
	await _physics(2)
	_expect(fell > 0.0 and mi.material_override == FireRuin.material() and cs.disabled, "it burns down where it stands: charred, its colliders off")
	_expect(not fire.ignite(hut) and not fire.is_burning(hut), "a ruin does not catch again")
	var r: FireRuin = null
	for x in fire.ruins:
		if is_instance_valid(x) and x.in_place == hut:
			r = x
	_expect(r != null and String(r.data.get("path", "")) == "TestHut", "its ruin is kept by its path in the level (%s)" % (r.data.get("path", "") if r else "none"))
	var ni := nextdoor.get_instance_id()
	await _until(func() -> bool: return _gone(ni), 150.0)


# --- What is in a piece --------------------------------------------------------------------------------------

func _test_contents() -> void:
	var cr := _piece("cradle", 21.0, 190.0)
	await _frames(2)
	var crn := cr.get_node_or_null("Cradle")
	_expect(crn != null and crn.is_in_group(Cradle.GROUP), "a built cradle is a cradle")
	fire.ignite(cr)
	_expect(crn != null and not crn.is_in_group(Cradle.GROUP), "alight, it is no place to lay the baby (out of the cradles group)")
	fire.put_out(cr)
	_expect(crn != null and crn.is_in_group(Cradle.GROUP) and not fire.is_burning(cr), "put out, a cradle again")
	# a chest with something in it: the player near it is told
	var near := player.global_position + Vector3(6.0, 0.0, 6.0)
	var ch := _piece("storage_chest", near.x, near.z)
	await _frames(2)
	var chest := ch.get_node_or_null("Chest") as StorageChest
	if chest:
		chest.items = [{"kind": "log", "count": 2}]
	fire.ignite(ch)
	var said := String(player.interactor._notice.text) if player.interactor else ""
	_expect(said == "The storage chest is alight: what is in it will burn", "a chest alight with things in it: the player near it is told (%s)" % said)
	fire.put_out(ch)
	# a woodpile's logs char with it
	var wp := _piece("woodpile", 27.0, 190.0)
	await _frames(2)
	var pile := wp.get_node_or_null("Woodpile") as Woodpile
	if pile:
		pile.from_save(12)
	await _frames(1)
	fire.ignite(wp)
	_burn(wp).left = 50.0
	fire._fall(wp)                          # (alight all over and charred at once, down within FALL_S)
	var logs: Array = pile.find_children("*", "GeometryInstance3D", true, false) if pile else []
	_expect(not logs.is_empty() and logs.all(func(g: Node) -> bool: return (g as GeometryInstance3D).material_override == FireRuin.material()),
			"a woodpile's logs char with it (%d)" % logs.size())
	var wpi := wp.get_instance_id()
	await _until(func() -> bool: return _gone(wpi), FireSpread.FALL_S + 1.0)


# --- Ruins: built over, the slope, cleared away -------------------------------------------------------------

func _test_ruins() -> void:
	var r1w := _piece("wall", 21.0, 210.0)
	var r2w := _piece("wall", 24.0, 210.0)
	await _frames(2)
	fire.ignite(r1w)
	fire.ignite(r2w)
	fire._fall(r1w)
	fire._fall(r2w)
	var i1 := r1w.get_instance_id()
	var i2 := r2w.get_instance_id()
	await _until(func() -> bool: return _gone(i1) and _gone(i2), FireSpread.FALL_S + 2.0)
	await _frames(2)
	var ru1 := _ruin_at(21.0, 210.0)
	var ru2 := _ruin_at(24.0, 210.0)
	_expect(ru1 != null and ru2 != null, "two walls side by side burnt to ruins")
	if ru1 == null or ru2 == null:
		return
	# the stubs stand RUIN_H over the ground at both ends: the cut follows the ground's slope
	var gi := ru2._gis[0] if not ru2._gis.is_empty() else null
	var slope: Vector2 = gi.get_instance_shader_parameter(&"cut_slope") if gi else Vector2.ZERO
	var at: Vector2 = gi.get_instance_shader_parameter(&"cut_at") if gi else Vector2.ZERO
	var cut := float(gi.get_instance_shader_parameter(&"cut_y")) if gi else 0.0
	var worst := 0.0
	for x: float in [ru2._box.position.x + 0.05, ru2._box.end.x - 0.05]:
		var z := ru2._box.get_center().z
		var stands := cut + slope.dot(Vector2(x, z) - at) - FrontierTerrain.height_at(x, z)
		worst = maxf(worst, absf(stands - float(FireRuin.RUIN_H.wall)))
	report["ruin_slope"] = [slope.x, slope.y]
	_expect(slope == FireRuin.ground_slope(ru2._box) and worst < 0.12, "the stubs stand %.2f m over the ground at both ends (within %.2f; the slope %s)" % [
			float(FireRuin.RUIN_H.wall), worst, slope])
	# a wall rebuilt on the first: its ruin cleared; the second's, touching its end, stays
	var nr := fire.ruins.size()
	var nw := _piece("wall", 21.0, 210.0)
	await _frames(1)
	fire.step(FireSpread.TICK_S)
	await _frames(1)
	_expect(_gone(ru1) and fire.ruins.size() == nr - 1, "a wall built again on a ruin clears the ruin away (no charred stubs through it)")
	_expect(not _gone(ru2) and fire.ruins.has(ru2), "the ruin touching its end stays")
	# build mode's Take down clears a ruin away
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	if mode == null:
		_expect(false, "the player has build mode")
		return
	var keep := player.global_position
	player.global_position = Vector3(24.0, FrontierTerrain.height_at(24.0, 206.0) + 0.1, 206.0)
	mode.set_active(true)
	mode.select(mode.data.order.size())
	mode.aim_at = Vector3(24.4, FrontierTerrain.height_at(24.4, 210.0), 210.0)
	await _physics(6)
	var said := String(ru2.interact_prompt(player))
	_expect(mode.taking_down() and said == "Clear away the burnt notched log wall", "in Take down, the crosshair on a ruin: E clears it away (%s)" % said)
	ru2.interact(player)
	await _frames(2)
	_expect(_gone(ru2) and fire.ruins.size() == nr - 2, "and it is gone")
	mode.aim_at = Vector3.INF
	mode.set_active(false)
	player.global_position = keep
	await _physics(2)
	world.remove_piece(nw)


# --- Pulled down alight: nothing back --------------------------------------------------------------------------

func _test_take_down() -> void:
	var mode := player.get_node_or_null("BuildMode") as BuildMode
	var tdw := _piece("wall", 30.0, 230.0)
	await _frames(2)
	fire.ignite(tdw)
	await _for(_burn(tdw).catch_s + 1.0)
	if mode == null:
		return
	mode.aimed_piece = tdw
	var prompt := mode.take_down_prompt()
	_expect(prompt.begins_with("Pull down the burning notched log wall"), "Take down on a burning wall: %s" % prompt)
	var logs0 := InventoryState.from_player(player).pack_count("log")
	var n0 := fire.ruins.size()
	_expect(mode.take_down(tdw), "it is pulled down")
	await _frames(2)
	var logs1 := InventoryState.from_player(player).pack_count("log")
	_expect(logs1 == logs0 and fire.ruins.size() == n0 + 1, "for nothing back (logs %d -> %d), its ruin left" % [logs0, logs1])
	mode.aimed_piece = null


# --- Many alight: ignite_area and the budget, on through the falls -----------------------------------------------

func _test_area() -> void:
	var at := Vector3(68.0, 0.0, 136.0)
	var made: Array[BuiltPiece] = []
	for i in 5:
		for j in 4:
			made.append(_piece("wall" if (i + j) % 2 == 0 else "palisade", at.x - 8.0 + i * 4.0, at.z - 6.0 + j * 4.0))
	var ids := made.map(func(p: BuiltPiece) -> int: return p.get_instance_id())
	var all_gone := func() -> bool: return ids.all(func(i: int) -> bool: return _gone(i))
	await _frames(2)
	at.y = FrontierTerrain.height_at(at.x, at.z)
	var n := fire.ignite_area(at, 12.0)
	_expect(n == 20, "ignite_area sets the 20 pieces round it alight (%d)" % n)
	var falls_at := {}
	var fell := [0]
	var on_fall := func(_t: String, _a: Vector3) -> void: fell[0] += 1
	fire.collapsed.connect(on_fall)
	var t := 0.0
	var k := 0
	var peak := 0
	var first := -1
	var max_falls := 0
	var char_ticks := {}
	var charred_before := 0
	var steady_total := 0
	var steady_n := 0
	var lit_ok := false
	var light_ok := false
	var column_ok := false
	var catch_end := FireSpread.CATCH_S * (1.0 + FireSpread.PACE) + 1.0
	while t < 200.0:
		fell[0] = 0
		fire.step(FireSpread.TICK_S)
		t += FireSpread.TICK_S
		k += 1
		if first < 0:
			first = fire.last_step_us
		peak = maxi(peak, fire.last_step_us)
		if fell[0] > 0:
			falls_at[k] = fell[0]
			max_falls = maxi(max_falls, fell[0])
		var charred := 0
		for b: FireSpread.Burn in fire._burns.values():
			if b.charred:
				charred += 1
		if charred > charred_before:
			char_ticks[k] = charred - charred_before
		charred_before = charred
		if not lit_ok and t >= catch_end:
			var lit := 0
			for i: int in ids:
				if fire.stage_of(instance_from_id(i)) in ["burning", "charred"]:
					lit += 1
			lit_ok = lit == 20
			_expect(lit_ok, "all 20 burn (%d; %d alight in all)" % [lit, fire.burning_count()])
			light_ok = (fire._light.visible or fire._light_power > 0.0) and fire._light.shadow_enabled == false \
					and current_scene.find_children("*", "OmniLight3D", true, false).filter(func(l: Node) -> bool: return fire.is_ancestor_of(l)).size() == 1
			column_ok = not fire._columns.is_empty()
			report["burning"] = fire.burning_count()
		elif lit_ok and steady_n < 40:
			steady_total += fire.last_step_us
			steady_n += 1
		if k % 8 == 0:
			await process_frame
		if all_gone.call():
			break
	fire.collapsed.disconnect(on_fall)
	var mean := steady_total / maxf(float(steady_n), 1.0)
	report["tick_us_20"] = mean
	report["tick_us_peak_through_falls"] = peak
	report["first_tick_us"] = first
	report["falls_ticks"] = falls_at.size()
	report["char_ticks"] = char_ticks.size()
	report["burnt_through_s"] = t
	_expect(light_ok, "one shared light at the burning area nearest the camera, no shadows")
	_expect(column_ok, "a smoke column over the burning area (%d)" % fire._columns.size())
	_expect(mean < 1000.0, "the fire's tick with 20 alight: %.0f µs (once every %.2f s, so %.0f µs a frame at 60 fps)" % [
			mean, FireSpread.TICK_S, mean / (FireSpread.TICK_S * 60.0)])
	_expect(all_gone.call(), "all 20 burn through and fall (%.0f s)" % t)
	_expect(max_falls <= FireSpread.FALLS_PER_TICK and falls_at.size() >= 10,
			"never more than %d fall in one tick (at most %d; the falls over %d ticks)" % [FireSpread.FALLS_PER_TICK, max_falls, falls_at.size()])
	_expect(char_ticks.size() >= 6, "they turn charred over %d ticks, not all in one" % char_ticks.size())
	_expect(peak < 2000, "the dearest tick of the whole burn, first catching, charring and falls: %d µs (the first %d µs)" % [peak, first])


# --- Save ----------------------------------------------------------------------------------------------------

func _test_save() -> void:
	_expect(SaveGame.PARTS.has("fire") and SaveGame.PARTS.find("fire") > SaveGame.PARTS.find("building"), "the save has a fire part, after the building")
	_expect(NetSession.WORLD_PARTS.has("fire") and NetSession.WORLD_PARTS.find("fire") > NetSession.WORLD_PARTS.find("building"),
			"a player joining gets the fire part with the host's world")
	var s1 := _piece("wall", 21.0, 250.0)
	var s2 := _piece("wall", 24.0, 250.0)
	await _frames(2)
	fire.ignite(s1)
	fire.ignite(s2)
	await _until(func() -> bool: return fire.stage_of(s1) == "charred", 60.0)
	var nr := fire.ruins.size()
	var nb := fire.burning_count()
	var nburnt := fire.burned_count()
	var some_id := s1.piece_id
	var doc: Variant = JSON.parse_string(JSON.stringify(SaveParts.plain(SaveParts.save_fire(current_scene))))
	_expect(doc is Dictionary and (doc.ruins as Array).size() == nr and (doc.burning as Array).size() == nb,
			"saved: %d ruins, %d alight, %d burnt" % [nr, nb, nburnt])
	if not (doc is Dictionary):
		return
	# a story's cabin alight and another burnt, saved by their paths; the mission has not made them yet when it loads
	var hut_at := Vector3(60.0, 0.0, 250.0)
	hut_at.y = FrontierTerrain.height_at(hut_at.x, hut_at.z)
	var ruin_at := Vector3(70.0, 0.0, 250.0)
	ruin_at.y = FrontierTerrain.height_at(ruin_at.x, ruin_at.z)
	(doc.burning as Array).append({"path": "LaterHut", "stage": FireSpread.STAGE_BURNING, "t": 5.0, "left": 30.0, "total": 40.0, "at": SaveParts.v3(hut_at)})
	(doc.ruins as Array).append({"path": "LaterRuin", "box": [SaveParts.v3(ruin_at - Vector3(2, 0, 2)), SaveParts.v3(Vector3(4, 3, 4))], "age": 10.0})
	fire.clear()
	await _frames(2)
	_expect(fire.ruins.is_empty() and fire.burning_count() == 0, "put out and cleared")
	SaveParts.load_fire(current_scene, doc)
	await _frames(2)
	_expect(fire.ruins.size() == nr and fire.burning_count() == nb and fire.burned_count() == nburnt,
			"loaded: %d ruins, %d alight, %d burnt" % [fire.ruins.size(), fire.burning_count(), fire.burned_count()])
	var p := world.by_id(some_id)
	_expect(p != null and fire.stage_of(p) == "charred", "a piece that was burning burns on, charred (%s)" % (fire.stage_of(p) if p else "none"))
	var r := _ruin_of("wall")
	_expect(r != null and not r.find_children("*", "GeometryInstance3D", true, false).is_empty(), "a wall's ruin is back, its charred stubs too")
	_expect(fire._pending.size() == 2, "the story's two not in the level yet are waited for (%d)" % fire._pending.size())
	var again: Dictionary = fire.save_data()
	_expect((again.burning as Array).size() == nb + 1 and (again.ruins as Array).size() == nr + 1, "and saved again meanwhile they are kept")
	var hut := _hut("LaterHut", hut_at)
	var later_ruin := _hut("LaterRuin", ruin_at)
	await _physics(2)
	await _for(1.25)
	_expect(fire._pending.is_empty() and fire.stage_of(hut) in ["burning", "charred"], "the mission's cabin made, it burns on as it was saved (%s)" % fire.stage_of(hut))
	_expect(not fire.ignite(later_ruin) and (later_ruin.get_node("Mesh") as MeshInstance3D).material_override == FireRuin.material(),
			"and the other is the ruin it was")


func _end() -> void:
	# (the household's navigation tiles rebake on the server's threads after the building changes: let them finish,
	# quitting under them aborts the engine on its way out, as tests/story/test_captivity.gd found)
	if fire and is_instance_valid(fire):
		fire.clear()
	var nw := NavWorld.of(self) if current_scene else null
	var guard := 0
	while nw != null and is_instance_valid(nw) and nw.baking() > 0 and guard < 600:
		await process_frame
		guard += 1
	await _frames(10)
	print("REPORT ", JSON.stringify(report))
	if fails.is_empty():
		print("FIRE TEST PASSED (%d checks)" % checks)
	else:
		for f in fails:
			printerr("FAIL: ", f)
		print("FIRE TEST FAILED (%d of %d)" % [fails.size(), checks])
	quit(0 if fails.is_empty() else 1)
