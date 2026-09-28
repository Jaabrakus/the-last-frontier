extends SceneTree
## Shared harness for the headless throwables tests (test_throwables.gd,
## test_throw_rules.gd). Loads the real level, installs the thrown weapons on the
## player with ThrowableKit.install(player) - player.gd has already registered them in
## player.weapons / weapon_order (keys 4-6, THROW), so this reuses them under
## player/Throwables and adds the stand-alone ThrowableArc - and ticks the active one the way
## player.gd ticks its weapon, driven by `scripted_input` instead of the mouse (the player's own
## weapon stays the pistol).

var player: FrontierPlayer
var kit: Dictionary
var cur: Throwable
var failures := PackedStringArray()
var checks := 0
var hits: Array = []
var cancels := 0
var fired := 0
## Roster as it was before install (the tests check it is unchanged).
var roster_before := {}
## Test boards made by _board (freed by _clear_boards).
var boards: Array[StaticBody3D] = []

const DT := 1.0 / 120.0


## Loads the level and installs the kit. False (after printing why) when it failed.
func _boot(keys: Array[String] = ThrowableKit.KEYS) -> bool:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	player = current_scene.get_node_or_null("Player") if current_scene else null
	if player == null:
		printerr("FAIL: level or player failed to load")
		return false
	player.ignore_mouse_capture = true
	_add_listener()
	roster_before = {"weapons": player.weapons.keys(), "order": player.weapon_order.duplicate()}
	kit = ThrowableKit.install(player, keys)
	for k in kit:
		var w: Throwable = kit[k]
		_script_defaults(w, k)
		w.use_scripted_input = true
		w.throw_cancelled.connect(func() -> void: cancels += 1)
		w.fired.connect(func() -> void: fired += 1)
	await _frames(30)
	# Keep the player's own weapon quiet and out of the way.
	player.switch_weapon("pistol")
	await _frames(40)
	if player.weapon and player.weapon.model:
		player.weapon.model.visible = false
	# Dummies that never topple, so every throw finds its target standing (health still
	# drops by exactly the damage dealt).
	for d in current_scene.find_children("*", "TargetDummy", true, false):
		(d as TargetDummy).max_health = 1.0e6
		(d as TargetDummy).health = 1.0e6
	return true


## player.gd registers the thrown weapons (THROW), which applies the weapon balance (hook H2) and
## lets the player's animation drive the release. These tests check the throwables' own mechanics at
## their script defaults (weapons_balance_design.md 1.7: the throwables tests run without the
## loader; the balanced numbers are tests/weapons/test_range_ladder.gd's): every exported setting
## goes back to a fresh instance's value (wait_for_anim_release off: the weapon's own timer).
func _script_defaults(w: Throwable, key: String) -> void:
	var fresh := ThrowableKit.create(key)
	if fresh == null:
		return
	for p in fresh.get_property_list():
		var u := int(p.usage)
		if (u & PROPERTY_USAGE_SCRIPT_VARIABLE) and (u & PROPERTY_USAGE_EDITOR) and String(p.name) != "count":
			w.set(p.name, fresh.get(p.name))
	fresh.free()


func _finish(label: String) -> void:
	if failures.is_empty():
		print("%s PASSED (%d checks)" % [label, checks])
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("%s FAILED (%d of %d)" % [label, failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _add_listener() -> void:
	var s := GDScript.new()
	s.source_code = "extends Node\nfunc _ready():\n\tadd_to_group('hit_listeners')\nfunc on_projectile_hit(c, p):\n\tget_meta('test').on_hit(c, p)\nfunc on_target_killed(t):\n\tpass\n"
	s.reload()
	var n := Node.new()
	n.set_script(s)
	n.set_meta("test", self)
	current_scene.add_child(n)


func on_hit(collider: Object, pos: Vector3) -> void:
	hits.append([collider, pos])


func _is_dummy(collider: Object) -> bool:
	return _dummy_of(collider) != null


func _dummy_of(collider: Object) -> TargetDummy:
	var n := collider as Node
	while n:
		if n is TargetDummy:
			return n
		n = n.get_parent()
	return null


## Physics frames; the active throwable is ticked like player.gd ticks its weapon.
func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		if cur and cur.active:
			cur.tick(DT)


func _use(key: String) -> Throwable:
	if cur:
		cur.unequip()
	cur = kit[key]
	cur.scripted_input = {"fire": false, "cancel": false}
	cur.equip()
	var arc := player.get_node("ThrowableArc") as ThrowableArc
	arc.source = cur
	await _frames(int(cur.equip_time * 120) + 10)
	return cur


func _fire(down: bool) -> void:
	cur.scripted_input["fire"] = down


func _cancel() -> void:
	cur.scripted_input["cancel"] = true


## Stands the player at `pos` (feet) facing `target` and aims the camera ray at it.
func _stand_and_aim(pos: Vector3, target: Vector3) -> void:
	player.global_position = pos + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	await _frames(30)
	for i in 5:
		var from := player.camera.global_position
		var d := target - from
		player.yaw = atan2(-d.x, -d.z)
		player.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _frames(3)


func _expect(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
	print(("  ok   " if cond else "  FAIL ") + msg)


## Winds up fully, throws, and returns the projectile (null if none came out).
func _full_throw() -> ThrownProjectile:
	_fire(true)
	for i in 240:
		await _frames(1)
		if cur.state == Throwable.State.HOLDING:
			break
	await _frames(6)
	var before := cur.last_thrown
	_fire(false)
	for i in 120:
		await _frames(1)
		if cur.last_thrown != before:
			break
	return cur.last_thrown if cur.last_thrown != before else null


## Waits until `p` stops (stuck / lying) or is freed. Returns its phase or -1.
## (Untyped: `p` may already have been picked up and freed.)
func _wait_rest(p, max_frames := 480) -> int:
	for i in max_frames:
		if not is_instance_valid(p):
			return -1
		if p.phase == ThrownProjectile.Phase.STUCK or p.phase == ThrownProjectile.Phase.LYING:
			return p.phase
		await _frames(1)
	return p.phase if is_instance_valid(p) else -1


## Walks the player up to `p` and waits for the pickup. True when it was picked up.
## (Untyped: `p` may already have been picked up and freed.)
func _pick_up(proj) -> bool:
	if not is_instance_valid(proj) or (proj as Node).is_queued_for_deletion():
		return false
	var p := proj as ThrownProjectile
	var spot := _stand_spot(p.global_position)
	player.global_position = spot + Vector3.UP * 0.3
	player.velocity = Vector3.ZERO
	# Face it and press E: nothing is picked up by walking over it since the E interaction (PlayerInteractor,
	# user 2026-09-25: "we need a item to highlight and we press e").
	_face(p.global_position)
	# E once the prompt is up (the item is highlighted: it arms a moment after it comes to rest)
	var pressed := -1
	for i in 120:
		await _frames(1)
		var it := player.interactor
		if pressed < 0 and it and is_instance_valid(p) and p.pickup and it.target == p.pickup:
			Input.action_press(ThrownPickup.INTERACT)
			pressed = i
		elif pressed >= 0 and i == pressed + 2:
			Input.action_release(ThrownPickup.INTERACT)   # (always: a key left down gives no next "just pressed")
		if pressed >= 0 and i >= pressed + 2 and (not is_instance_valid(p) or p.is_queued_for_deletion()):
			return true
	if Input.is_action_pressed(ThrownPickup.INTERACT):
		Input.action_release(ThrownPickup.INTERACT)
	var pk := p.pickup
	var it := player.interactor
	var cam := player.get_viewport().get_camera_3d()
	print("    pickup failed: item %s phase %d, player %s, reach %.2f m, taker %s | interactor target %s label '%s' armed %s prompt '%s' pk at %s cam fwd %s yaw %.2f" % [p.global_position, p.phase,
			player.global_position, pk.distance_from(player.global_position + Vector3.UP * 0.9) if pk else -1.0,
			ThrownPickup.find_taker(player, p.kind), it.target if it else null, it._label.text if it else "",
			pk.is_armed() if pk else false, pk.prompt(player) if pk else "", pk.global_position if pk else Vector3.ZERO,
			-cam.global_transform.basis.z if cam else Vector3.ZERO, player.yaw])
	return false


## Turns the player and its camera toward `at` (PlayerInteractor offers what is in front of the view).
func _face(at: Vector3) -> void:
	var to := at - player.global_position
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = deg_to_rad(-35.0)


## Where the player can stand next to `at` (feet position, on the ground): 0.7-1.0 m away,
## toward the player first, on the lowest ground around (not on top of a dummy, a board or
## a hay bale that the first ground ray would hit) and with room for the body.
func _stand_spot(at: Vector3) -> Vector3:
	var flat := Vector3(at.x, 0.0, at.z)
	var back := Vector3(player.global_position.x, 0.0, player.global_position.z) - flat
	back = back.normalized() if back.length_squared() > 1e-4 else Vector3.BACK
	var cands: Array[Vector3] = []
	var low := INF
	for r: float in [0.7, 1.0]:
		for i in 8:
			var s := flat + back.rotated(Vector3.UP, i * TAU / 8.0) * r
			var c := Vector3(s.x, _ground_at(s.x, s.z), s.z)
			cands.append(c)
			low = minf(low, c.y)
	var space := player.get_world_3d().direct_space_state
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	sq.shape = cap
	sq.exclude = [player.get_rid()]
	for c in cands:
		if c.y > low + 0.35:
			continue
		sq.transform = Transform3D(Basis.IDENTITY, c + Vector3.UP * 1.0)
		if space.intersect_shape(sq, 1).is_empty():
			return c
	return cands[0]


## Ground height under (x, z) (the first hit of a ray from 60 m up, see _ground_exclude).
func _ground_at(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -60.0, z))
	q.exclude = _ground_exclude()
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (r.position as Vector3).y if r else 0.0


## Bodies the ground ray ignores: the player and the test boards (so a board never stands
## on another one).
func _ground_exclude() -> Array[RID]:
	var excl: Array[RID] = [player.get_rid()]
	for bd in boards:
		if is_instance_valid(bd):
			excl.append(bd.get_rid())
	return excl


## A flat target board (w x h x 0.3 m) standing on the ground, facing +Z, that records
## every apply_hit. `surface` goes into the meta Sfx.surface_of reads.
func _board(x: float, z: float, surface: String, w := 1.6, h := 3.2) -> StaticBody3D:
	var s := GDScript.new()
	s.source_code = "extends StaticBody3D\nvar hit_log: Array = []\nfunc apply_hit(damage, point, dir, source, part):\n\thit_log.append({'damage': damage, 'point': point, 'source': source, 'part': part})\n"
	s.reload()
	var b := StaticBody3D.new()
	b.set_script(s)
	b.name = "TestBoard_" + surface
	b.set_meta(&"surface", surface)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.3)
	cs.shape = box
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.49, 0.46) if surface == "stone" else Color(0.45, 0.32, 0.2)
	mat.roughness = 0.9
	mi.material_override = mat
	b.add_child(mi)
	var y := _ground_at(x, z)
	current_scene.add_child(b)
	b.global_position = Vector3(x, y + h * 0.5, z)
	boards.append(b)
	return b


func _clear_boards() -> void:
	for b in boards:
		if is_instance_valid(b):
			b.queue_free()
	boards.clear()


## Spread off (exact aim) for `w`; returns the old values for _restore_spread.
func _no_spread(w: Throwable) -> Array:
	var keep := [w.spread_base, w.spread_move, w.spread_undercharge, w.fire_bloom, w.spread_air, w.spread_fatigue]
	w.spread_base = 0.0
	w.spread_move = 0.0
	w.spread_undercharge = 0.0
	w.fire_bloom = 0.0
	w.spread_air = 0.0
	w.spread_fatigue = 0.0
	w._bloom = 0.0
	w.spread = 0.0
	return keep


func _restore_spread(w: Throwable, keep: Array) -> void:
	w.spread_base = keep[0]
	w.spread_move = keep[1]
	w.spread_undercharge = keep[2]
	w.fire_bloom = keep[3]
	w.spread_air = keep[4]
	w.spread_fatigue = keep[5]


## A forest tree trunk (group "trees") 22-60 m from the fort centre that can be hit from
## 7 m with nothing in the way: {stand (feet), aim (trunk, 1.4 m up)}, or {} if none.
func _find_tree() -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var found: Array = []
	for body in current_scene.get_tree().get_nodes_in_group(&"trees"):
		for c in (body as Node).get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is CylinderShape3D):
				continue
			var r := (cs.shape as CylinderShape3D).radius
			var base := cs.global_position - Vector3.UP * (cs.shape as CylinderShape3D).height * 0.5
			var flat := Vector2(base.x, base.z)
			if r < 0.15 or flat.length() < 22.0 or flat.length() > 60.0:
				continue
			found.append([flat.length(), cs, r, base])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for f: Array in found:
		var base: Vector3 = f[3]
		var r: float = f[2]
		var out := Vector3(-base.x, 0.0, -base.z).normalized()
		var sx := base.x + out.x * 7.0
		var sz := base.z + out.z * 7.0
		var gy := _ground_at(sx, sz)
		var trunk_y := _ground_at(base.x + out.x * (r + 0.05), base.z + out.z * (r + 0.05))
		if absf(gy - trunk_y) > 0.8:
			continue
		var aim := Vector3(base.x, trunk_y + 1.4, base.z)
		var ok := true
		for h: float in [1.3, 1.6, 2.3]:
			var from := Vector3(sx, gy + h, sz)
			var q := PhysicsRayQueryParameters3D.create(from, aim)
			q.exclude = [player.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty() or Vector2(hit.position.x - base.x, hit.position.z - base.z).length() > r + 0.1:
				ok = false
				break
		# Room to stand.
		var sq := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.5
		cap.height = 1.6
		sq.shape = cap
		sq.transform = Transform3D(Basis.IDENTITY, Vector3(sx, gy + 1.0, sz))
		sq.exclude = [player.get_rid()]
		if ok and space.intersect_shape(sq, 1).is_empty():
			return {"stand": Vector3(sx, gy, sz), "aim": aim}
	return {}
